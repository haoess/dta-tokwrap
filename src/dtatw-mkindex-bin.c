#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#undef XML_DTD
#undef XML_NS
#undef XML_UNICODE
#undef XML_UNICODE_WHAT_T
#define XML_CONTEXT_BYTES 1024
#include <expat.h>

/*======================================================================
 * Globals
 */

//-- ENABLE_ASSERT : if defined, debugging assertions will be enabled
#define ENABLE_ASSERT 1
//#undef ENABLE_ASSERT

//-- NIL_ID: string used for missing xml:id attributes on <c> elements
const char *NIL_ID = "-";

//-- LB_ID : pseudo-ID for <lb/> records
const char *LB_ID = "$LB$";

#define BUFSIZE     8192 //-- file input buffer size
#define CTBUFSIZE    256 //-- <c>-local text buffer size
#define CIDBUFSIZE   256 //-- <c>-local xml:id buffer size

typedef long unsigned int ByteOffset;
typedef int ByteLen;

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_cx;           //-- output character-index file
  FILE *f_sx;           //-- output structure-index file
  FILE *f_tx;           //-- output text file
  int text_depth;       //-- boolean: number of open 'text' elements
  int total_depth;      //-- boolean: total depth
  ByteOffset n_chrs;    //-- number of <c> elements read
  int is_c;             //-- boolean: true if currently parsing a 'c' elt
  int is_chardata;      //-- true if current event is character data
  ByteOffset loc_xoff;  //-- last xml-offset written to .sx as location-block (see LOC_FMT, cb_default())
  ByteOffset loc_toff;  //-- last text-offset written to .sx as location-block (see LOC_FMT, cb_default())
  XML_Char c_tbuf[CTBUFSIZE]; //-- text buffer for current <c>
  int c_tlen;                 //-- byte length of text in character buffer c_tbuf[]
  XML_Char c_id[CIDBUFSIZE];  //-- xml:id of current <c>
  ByteOffset c_xoffset; //-- byte offset in XML stream at which current <c> started
  ByteOffset c_toffset; //-- byte offset in text stream at which current <c> started
} TokWrapData;

//-- prog: default name of this program (used for error reporting, set from argv[0] later)
char *prog = "dtatw-mkindex";

//-- want_profile: if true, some profiling information will be printed to stderr
int want_profile = 1;

//-- want_outfile_comments: if true, some explanatory comments will be printed to the output file
int want_outfile_comments = 1;

//-- want_outfile_format_colnames: if true, column names will be printed as the first record
// + column names will be commented if want_outfile_comments is true as well
int want_outfile_colnames = 1;

/*======================================================================
 * Debug
 */

#if !defined(assert)
# if defined(ENABLE_ASSERT)
#  define assert(test) if (!(test)) { fprintf(stderr, "%s: %s:%d: assertion failed: (%s)\n", prog, __FILE__, __LINE__, #test); exit(255); }
# else  /* defined(ENABLE_ASSERT) -> false */
#  define assert(test) 
# endif /* defined(ENABLE_ASSERT) */
#endif /* !defined(assert) */

//-- SX_IGNORE_WS : ignore whitespace-only text events for .sx output
#define SX_IGNORE_WS 1

/*======================================================================
 * Utils
 */

//--------------------------------------------------------------
typedef struct _dtatwCxHeader {
  char magic[32];
  unsigned int fileversion;
} dtatwCxHeader;

void print_cx_header(FILE *f, int argc, char **argv)
{
  dtatwCxHeader hdr;
  if (!f) return;

  snprintf(hdr.magic, sizeof(hdr.magic), "dtatw-mkindex:cx\n");
  hdr.fileversion = 1;

  fwrite(&hdr, sizeof(dtatwCxHeader),1, f);
}

//--------------------------------------------------------------
const XML_Char *get_attr(const XML_Char *aname, const XML_Char **attrs)
{
  int i;
  for (i=0; attrs[i]; i += 2) {
    if (strcmp(aname,attrs[i])==0) return attrs[i+1];
  }
  return NULL;
}

/*--------------------------------------------------------------
 * index_text()
 *  + escape text for printing in index
 */
char index_txtbuf[CTBUFSIZE];
char *index_text(const char *buf, int len)
{
  int i,j;
  char *out = index_txtbuf;
  for (i=0,j=0; (len < 0 || i < len) && buf[i]; i++) {
    switch (buf[i]) {
    case '\\':
      out[j++] = '\\';
      out[j++] = '\\';
      break;
    case '\t':
      out[j++] = '\\';
      out[j++] = 't';
      break;
    case '\n':
      out[j++] = '\\';
      out[j++] = 'n';
      break;
    default:
      out[j++] = buf[i];
      break;
    }
  }
  out[j++] = '\0';
  return out;
}

//--------------------------------------------------------------
void put_raw_text(TokWrapData *data, int tlen, const char *txt)
{
  if (data->f_tx) fwrite(txt, 1,tlen, data->f_tx);
  data->c_toffset += tlen;
}

//--------------------------------------------------------------
#define CXBIN_NULSTRINGS 1 //-- use NUL-terminated strings instead of fixed-width fields
#ifndef CXBIN_NULSTRINGS
# define BINLEN_ID   12 //-- == 2 + length(2**32-1 (=4294967295))
# define BINLEN_TEXT  4 //-- == UTF-8 max?
#endif

void put_record_raw(FILE *f, const char *id, ByteOffset xoffset, int xlen, ByteOffset toffset, int tlen, const char *txt)
{
  unsigned char xlen_c = xlen;
  unsigned char tlen_c = tlen;
  int strlen_id  = strlen(id);
  int strlen_txt = (tlen < 0 ? strlen(txt) : tlen);
  int i;

  if (!f) return;
  //fprintf(f, "%s\t%lu\t%d\t%lu\t%d\t%s\n", id, xoffset, xlen, toffset, (tlen < 0 ? 0 : tlen), index_text(txt,tlen));

  //-- id, NUL-terminated
  fwrite(id, 1,strlen_id, f);
#ifdef CXBIN_NULSTRINGS
  fputc('\0', f);
#else
  assert(strlen_id<=BINLEN_ID);
  for (i=strlen_id; i < BINLEN_ID; i++) { fputc('\0', f); }
#endif
  
  //-- xoffset, xlen
  fwrite(&xoffset, sizeof(ByteOffset),1, f);
  fwrite(&xlen_c,  sizeof(unsigned char),1, f);

  //-- toffset, tlen
  fwrite(&toffset, sizeof(ByteOffset),1, f);
  fwrite(&tlen_c,  sizeof(unsigned char),1, f);

  //-- txt
  fwrite(txt, 1,strlen_txt, f);
#ifdef CXBIN_NULSTRINGS
  fputc('\0', f);
#else
  for (i=strlen_txt; i < BINLEN_TEXT; i++) { fputc('\0', f); }
#endif

  return;
}

//--------------------------------------------------------------
void put_record_char(TokWrapData *data)
{
  ByteOffset c_xlen = XML_GetCurrentByteIndex(data->xp) + XML_GetCurrentByteCount(data->xp) - data->c_xoffset;
  put_record_raw(data->f_cx,
		 data->c_id,
		 data->c_xoffset, c_xlen,
		 data->c_toffset, data->c_tlen,
		 data->c_tbuf
		 );
  put_raw_text(data, data->c_tlen, data->c_tbuf);
  data->c_tlen = 0; //-- reset
}

//--------------------------------------------------------------
void put_record_lb(TokWrapData *data)
{
  ByteOffset c_xlen = XML_GetCurrentByteIndex(data->xp) + XML_GetCurrentByteCount(data->xp) - data->c_xoffset;
  put_record_raw(data->f_cx,
		 LB_ID,
		 data->c_xoffset, c_xlen,
		 data->c_toffset, 1,
		 "\n"
		 );
  put_raw_text(data, 1, "\n");
}

/*--------------------------------------------------------------
 * get_error_context()
 *  + gets error context
 */
const char *get_error_context(XML_Parser xp, int ctx_want, int *offset, int *len)
{
  int ctx_offset, ctx_size;
  const char *ctx_buf = XML_GetInputContext(xp, &ctx_offset, &ctx_size);
  int ctx_mystart, ctx_myend;
  ctx_mystart = ((ctx_offset <= ctx_want)              ? 0        : (ctx_offset-ctx_want));
  ctx_myend   = ((ctx_size   <= (ctx_offset+ctx_want)) ? ctx_size : (ctx_offset+ctx_want));
  *offset = ctx_offset - ctx_mystart;
  *len    = ctx_myend - ctx_mystart;
  return ctx_buf + ctx_mystart;
}

/*--------------------------------------------------------------
 * get_event_context()
 *  + gets current event context (analagous to perl XML::Parser::original_string())
 */
const char *get_event_context(XML_Parser xp, int *len)
{
  int ctx_offset, ctx_size;
  const char *ctx_buf = XML_GetInputContext(xp, &ctx_offset, &ctx_size);
  int cur_size = XML_GetCurrentByteCount(xp);
  assert(ctx_offset >= 0);
  assert(ctx_offset+cur_size <= ctx_size);
  *len = cur_size;
  return ctx_buf + ctx_offset;
}


/*--------------------------------------------------------------
 * g = si_g(f)
 */

double si_val(double g)
{
  if (g >= 1e12) return g / 1e12;
  if (g >= 1e9) return g / 1e9;
  if (g >= 1e6) return g / 1e6;
  if (g >= 1e3) return g / 1e3;
  return g;
}

const char *si_suffix(double g)
{
  if (g >= 1e12) return "T";
  if (g >= 1e9) return "G";
  if (g >= 1e6) return "M";
  if (g >= 1e3) return "K";
  return "";
}



/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (data->text_depth && strcmp(name,"c")==0) {
    const char *id;
    if (data->is_c) {
      fprintf(stderr, "%s: cannot handle nested <c> elements starting at bytes %lu, %lu\n",
	      prog, data->c_xoffset, XML_GetCurrentByteIndex(data->xp));
      exit(3);
    }
    if ( (id=get_attr("xml:id", attrs)) ) {
      assert(strlen(id) < CIDBUFSIZE);
      strcpy(data->c_id,id);
    } else {
      assert(strlen(NIL_ID) < CIDBUFSIZE);
      strcpy(data->c_id,NIL_ID);
    }
    data->c_xoffset = XML_GetCurrentByteIndex(data->xp);
    data->c_tlen    = 0;
    data->is_c      = 1;
    data->n_chrs++;
    data->total_depth++;
    return;
  }
  else if (strcmp(name,"lb")==0) {
    put_record_lb(data);
    data->total_depth++;
    return;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth++;
  }
  data->is_chardata = 0;
  XML_DefaultCurrent(data->xp);
  data->total_depth++;
}

//--------------------------------------------------------------
void cb_end(TokWrapData *data, const XML_Char *name)
{
  if (strcmp(name,"c")==0) {
    put_record_char(data);  //-- output: index record + raw text
    data->is_c = 0;         //-- ... and leave <c>-parsing mode
    data->total_depth--;
    return;
  }
  else if (strcmp(name,"lb")==0) {
    data->total_depth--;
    return;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth--;
  }
  data->is_chardata = 0;
  XML_DefaultCurrent(data->xp);
  data->total_depth--;

}

//--------------------------------------------------------------
void cb_char(TokWrapData *data, const XML_Char *s, int len)
{
  if (data->is_c) {
    assert(data->c_tlen + len < CTBUFSIZE);
    memcpy(data->c_tbuf+data->c_tlen, s, len); //-- copy required, else clobbered by nested elts (e.g. <c><g>...</g></c>)
    data->c_tlen += len;
    return;
  }
#ifdef SX_IGNORE_WS
  else {
    int i;
    int isws=1;
    for (i=0; i<len; i++) {
      if (!isspace(s[i])) { isws=0; break; }
    }
    if (isws) return;
  }
#endif /* SX_IGNORE_WS */
  data->is_chardata = 1;
  XML_DefaultCurrent(data->xp);
}

//--------------------------------------------------------------
static const char *LOC_FMT = "<c n=\"%lu %lu %lu %lu\"/>"; //-- xoff xlen toff tlen
//static const char *LOC_FMT = "<c n=\"%lu %lu\"/>";
//static const char *LOC_FMT = "<dta.tw.b n=\"%lu %lu\"/>";
//static const char *LOC_FMT = "<dta.tw.block xb=\"%lu\" tb=\"%lu\"/>";
//static const char *LOC_FMT = "<milestone unit=\"dta.loc\" n=\"%lu %lu\"/>";
void cb_default(TokWrapData *data, const XML_Char *s, int len)
{
  int ctx_len;
  if (!data->f_sx) return;
  const XML_Char *ctx = get_event_context(data->xp, &ctx_len);
  ByteOffset xoff = XML_GetCurrentByteIndex(data->xp);
  if (data->total_depth > 0 && !data->is_chardata && xoff != data->loc_xoff) {
    //-- pre-event location element
    ByteOffset xlen = xoff - data->loc_xoff;
    ByteOffset tlen = data->c_toffset + data->c_tlen - data->loc_toff;
    fprintf(data->f_sx, LOC_FMT, data->loc_xoff, xlen, data->loc_toff, tlen);
    data->loc_xoff = xoff;
    data->loc_toff = data->c_toffset + data->c_tlen;
  }
  fwrite(ctx, 1,ctx_len, data->f_sx);
  if (data->total_depth > 1 && !data->is_chardata && xoff+ctx_len != data->loc_xoff) {
    //-- post-event location element
    ByteOffset xlen = xoff + ctx_len - data->loc_xoff;
    ByteOffset tlen = data->c_toffset + data->c_tlen - data->loc_toff;
    fprintf(data->f_sx, LOC_FMT, data->loc_xoff, xlen, data->loc_toff, tlen);
    data->loc_xoff = xoff + ctx_len;
    data->loc_toff = data->c_toffset + data->c_tlen;
  }
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  TokWrapData data;
  XML_Parser xp;
  void *buf;
  int  isFinal = 0;
  char *filename_in = "-";
  char *filename_cx = "-";
  char *filename_sx = NULL;
  char *filename_tx = NULL;
  FILE *f_in = stdin;   //-- input file
  FILE *f_cx = stdout;  //-- output character-index file (NULL for none)
  FILE *f_sx = NULL;    //-- output structure-index file (NULL for none)
  FILE *f_tx = NULL;    //-- output text file (NULL for none)
  //
  //-- profiling
  double elapsed = 0;
  ByteOffset n_xbytes = 0;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s INFILE [CXFILE [SXFILE [TXFILE]]]\n", prog);
    fprintf(stderr, " + INFILE : XML source file with <c> and <lb> elements\n");
    fprintf(stderr, " + CXFILE : output character-index binary file; default=stdout\n");
    fprintf(stderr, " + SXFILE : output structure-index XML file; default=none\n");
    fprintf(stderr, " + TXFILE : output raw text-index file (unserialized); default=none\n");
    fprintf(stderr, " + \"-\" may be used in place of any filename to indicate standard (in|out)put\n");
    fprintf(stderr, " + \"\"  may be used in place of any output filename to discard output\n");
    exit(1);
  }
  //-- command-line: input file
  if (argc > 1) {
    filename_in = argv[1];
    if ( strcmp(filename_in,"-")!=0 && !(f_in=fopen(filename_in,"rb")) ) {
      fprintf(stderr, "%s: open failed for input file `%s': %s\n", prog, filename_in, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output character-index file
  if (argc > 2) {
    filename_cx = argv[2];
    if (strcmp(filename_cx,"")==0) {
      f_cx = NULL;
    }
    else if ( strcmp(filename_cx,"-")==0 ) {
      f_cx = stdout;
    }
    else if ( !(f_cx=fopen(filename_cx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output character-index file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output structure-index file
  if (argc > 3) {
    filename_sx = argv[3];
    if (strcmp(filename_sx,"")==0) {
      f_sx = NULL;
    }
    else if ( strcmp(filename_sx,"-")==0 ) {
      f_sx = stdout;
    }
    else if ( strcmp(filename_sx,filename_cx)==0 ) {
      f_sx = f_cx;
    }
    else if ( !(f_sx=fopen(filename_sx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output structure-index file `%s': %s\n", prog, filename_sx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output text file
  if (argc > 4) {
    filename_tx = argv[4];
    if (strcmp(filename_tx,"")==0) {
      f_tx = NULL;
    }
    else if ( strcmp(filename_tx,"-")==0 ) {
      f_tx = stdout;
    }
    else if ( !(f_tx=fopen(filename_tx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output text file `%s': %s\n", prog, filename_tx, strerror(errno));
      exit(1);
    }
  }

  //-- print output header(s)
  if (f_cx) print_cx_header(f_cx, argc, argv);
  /*if (f_sx && f_sx != f_cx) print_cx_header(f_sx, argc, argv);*/

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  if (!xp) {
    fprintf(stderr, "%s: XML_ParserCreate failed", prog);
    exit(1);
  }
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);
  XML_SetCharacterDataHandler(xp, (XML_CharacterDataHandler)cb_char);
  XML_SetDefaultHandler(xp, (XML_DefaultHandler)cb_default);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp   = xp;
  data.f_cx = f_cx;
  data.f_sx = f_sx;
  data.f_tx = f_tx;

  //-- parse input file
  do {
    size_t nread;
    int status;

    //-- setup & read into buffer (uses expat functions to avoid double-copy)
    buf = XML_GetBuffer(xp, BUFSIZE);
    if (!buf) {
      fprintf(stderr, "%s: XML_GetBuffer() failed!\n", prog);
      exit(1);
    }
    nread = fread(buf, 1,BUFSIZE, f_in);
    n_xbytes += nread;

    //-- check for file errors
    isFinal = feof(f_in);
    if (ferror(f_in) && !isFinal) {
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): I/O error: %s\n",
	      prog, filename_in,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      strerror(errno));
      exit(1);
    }

    status = XML_ParseBuffer(xp, (int)nread, isFinal);

    //-- check for expat errors
    if (status != XML_STATUS_OK) {
      int ctx_offset = 0, ctx_len = 0;
      const char *ctx_buf;
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): XML error: %s\n",
	      prog, filename_in,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      XML_ErrorString(XML_GetErrorCode(xp)));

      ctx_buf = get_error_context(xp, 64, &ctx_offset, &ctx_len);
      fprintf(stderr, "%s: Error Context:\n%.*s%s%.*s\n",
	      prog,
	      ctx_offset, ctx_buf,
	      "\n---HERE---\n",
	      (ctx_len-ctx_offset), ctx_buf+ctx_offset);
      exit(2);
    }
  } while (!isFinal);

  //-- terminate cx file with number of characters (NUL-terminated strings only)
#ifdef CXBIN_NULSTRINGS
  if (f_cx) {
    ByteOffset n_cx = data.n_chrs+1;
    fwrite(&n_cx, sizeof(ByteOffset),1, f_cx);
  }
#endif

  //-- always terminate text file with a newline
  if (f_tx) fputc('\n',f_tx);

  //-- profiling
  if (want_profile) {
    elapsed = ((double)clock()) / ((double)CLOCKS_PER_SEC);
    if (elapsed <= 0) elapsed = 1e-5;
    fprintf(stderr, "%s: %.2f%s XML chars ~ %.2f%s XML bytes in %.2f sec: %.2f %schar/sec ~ %.2f %sbyte/sec\n",
	    prog,
	    si_val(data.n_chrs),si_suffix(data.n_chrs),
	    si_val(n_xbytes),si_suffix(n_xbytes),
	    elapsed, 
	    si_val(data.n_chrs/elapsed),si_suffix(data.n_chrs/elapsed),
	    si_val(n_xbytes/elapsed),si_suffix(n_xbytes/elapsed));
  }

  //-- cleanup
  if (f_in) fclose(f_in);
  if (f_cx) fclose(f_cx);
  if (f_sx && f_sx != f_cx) fclose(f_sx);
  if (f_tx && f_tx != f_cx && f_tx != f_sx) fclose(f_tx);
  if (xp) XML_ParserFree(xp);

  return 0;
}
