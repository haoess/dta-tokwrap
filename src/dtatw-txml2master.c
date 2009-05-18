#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
#define VERBOSE_IO 1
//#undef VERBOSE_IO

// VERBOSE_INIT : whether to print progress messages for initialize & allocate
#if VERBOSE_IO
# define VERBOSE_INIT 1
#else
# undef VERBOSE_INIT
#endif

// CXML_ADJACENCY_TOLERANCE
//  + number of bytes which may appear between end of one <c> and beginning of the next <c>
//    while still allowing them to be considered "adjacent"
//  + no guarantee is made for the content of such bytes, if they exist!
//  + a value of 0 (zero) gives a safe, strict adjanency criterion
//  + a value of 1 (one) allows e.g. UNIX-style newlines ("\n") between <c>s
//  + a value of 2 (two) allows e.g. DOS-style newlines ("\r\n") between <c>s
//  + a value of 7 (secen) allows e.g. redundantly coded ("<lb/>\r\n") between <c>s
#define CXML_ADJACENCY_TOLERANCE 0

//-- xml structure constants (should jive with 'tok2xml')
const char *sElt   = "s";          //-- .t.xml sentence element
const char *wElt   = "w";          //-- .t.xml token element
const char *posAttr = "b";         //-- .t.xml byte-position attribute
const char *cAttr    = "c";        //-- .t.xml token-chars attribute (space-separated xml:ids from .cx file)
const char *idAttr   = "xml:id";   //-- .t.xml id attribute


//-- output xml structure constants (should jive with TEI, DTA "master" format)
#define REF_ATTR "n"
#define REF_HASH "#"

/*======================================================================
 * Utils: .cx, .tx, .bx files (see also dtatwCommon.[ch])
 */
cxData cxdata = {NULL,0,0};       //-- cxRecord *cx = &cxdata->data[c_index]
bxData bxdata = {NULL,0,0};       //-- bxRecord *bx = &bxdata->data[block_index]

Offset2CxIndex txb2cx = {NULL,0};   //-- cxRecord *cx =  txb2cx->data[ tx_byte_index]
Offset2CxIndex txtb2cx = {NULL,0};  //-- cxRecord *cx = txtb2cx->data[txt_byte_index]

/*======================================================================
 * Utils: .t.xml file(s): general
 */

//--------------------------------------------------------------

// TXML_ID_BUFLEN : buffer length for IDs in fixed-with token records
#define TXML_ID_BUFLEN 16

typedef struct {
  ByteOffset  s_i;                    //-- index of sentence claiming this token
  char        w_id[TXML_ID_BUFLEN];   //-- xml:id of this token
  ByteOffset  w_txtoff;               //-- .txt-byte offset of this <w>
  ByteOffset  w_txtlen;               //-- .txt-byte length of this <w>
  short       w_nsegs;                //-- number of (discontinuous) segments this token requires
  short       w_seg;                  //-- index of next segment awaited (w_seg < w_nsegs)
} txmlToken;

typedef struct {
  char        s_id[TXML_ID_BUFLEN];   //-- xml:id of this sentence
  txmlToken  *w_first;                //-- pointer to first <w> of this <s>
  txmlToken  *w_last;                 //-- pointer to last  <w> of this <s>
  short       s_nsegs;                //-- number of (discontinuous) segments this sentence requires
  short       s_seg;                  //-- index of next segment awaited (s_seg < s_nsegs)
} txmlSentence;


typedef struct {
  txmlSentence *s_data;     //-- sentence data vector
  ByteOffset    s_len;      //-- number of populated sentence records
  ByteOffset    s_alloc;    //-- number of allocated sentence records
  //
  txmlToken    *w_data;     //-- token data vector
  ByteOffset    w_len;      //-- number of populated token records
  ByteOffset    w_alloc;    //-- number of allocated token records
} txmlData;

#ifndef TXML_DEFAULT_SALLOC
# define TXML_DEFAULT_SALLOC 8192
#endif
#ifndef TXML_DEFAULT_WALLOC
# define TXML_DEFAULT_WALLOC 8192
#endif

//-- txmlToken     *tok = &txmldata->wdata[token_index]
//-- txmlSentence *sent = &txmldata->sdata[sentence_index]
txmlData txmldata = { NULL,0,0, NULL,0,0 };

//--------------------------------------------------------------
typedef struct {
  ByteOffset w_i;       //-- index of token claiming this <c>    [NOT a pointer, since realloc() invalidates those!]
  ByteOffset s_i;       //-- index of sentence claiming this <c> [ditto]
  unsigned w_ok    : 1; //-- set iff this <c> is claimed by some <w>
  unsigned s_ok    : 1; //-- set iff this <c> is claimed by some <s>
  unsigned w_begin : 1; //-- set iff this <c> begins its <w>
  unsigned w_end   : 1; //-- set iff this <c> ends its <w>
} cxAuxRecord;

cxAuxRecord  *cxaux = NULL; //-- cxAuxRecord *cxa = &cxaux[c_index]

//--------------------------------------------------------------
txmlData *txmlDataInit(txmlData *txd, size_t sent_size, size_t tok_size)
{
  //-- init: txd
  if (!txd) {
    txd = (txmlData*)malloc(sizeof(txmlData));
    assert(txd != NULL /* malloc failed */);
  }

  //-- init: sentences
  if (sent_size==0) sent_size = TXML_DEFAULT_SALLOC;
  txd->s_data = (txmlSentence*)malloc(sent_size*sizeof(txmlSentence));
  assert(txd->s_data != NULL /* malloc failed */);
  txd->s_len   = 0;
  txd->s_alloc = sent_size;

  //-- init: tokens
  if (tok_size==0) tok_size = TXML_DEFAULT_WALLOC;
  txd->w_data = (txmlToken*)malloc(tok_size*sizeof(txmlToken));
  assert(txd->w_data != NULL /* malloc failed */);
  txd->w_len   = 0;
  txd->w_alloc = tok_size;

  //-- return
  return txd;
}

//--------------------------------------------------------------
txmlSentence *txmlDataPushSentence(txmlData *txd, txmlSentence *sx)
{
  if (txd->s_len+1 >= txd->s_alloc) {
    //-- whoops: must reallocate
    txd->s_data = (txmlSentence*)realloc(txd->s_data, txd->s_alloc*2*sizeof(txmlSentence));
    assert(txd->s_data != NULL /* realloc failed */);
    txd->s_alloc *= 2;
  }
  //-- just copy raw data, pointers & all
  //  + i.e. if you need a pointer copied, do it before calling this function!
  memcpy(&txd->s_data[txd->s_len], sx, sizeof(txmlSentence));
  return &txd->s_data[txd->s_len++];
}

//--------------------------------------------------------------
txmlToken *txmlDataPushToken(txmlData *txd, txmlToken *tx)
{
  if (txd->w_len+1 >= txd->w_alloc) {
    //-- whoops: must reallocate
    txd->w_data = (txmlToken*)realloc(txd->w_data, txd->w_alloc*2*sizeof(txmlToken));
    assert(txd->w_data != NULL /* realloc failed */);
    txd->w_alloc *= 2;
  }
  //-- just copy raw data, pointers & all
  //  + i.e. if you need a pointer copied, do it before calling this function!
  memcpy(&txd->w_data[txd->w_len], tx, sizeof(txmlToken));
  return &txd->w_data[txd->w_len++];
}


//--------------------------------------------------------------
typedef struct {
  XML_Parser   xp;             //-- underlying expat parser
  txmlData    *txd;            //-- vector of token records being populated
  txmlToken    w_cur;          //-- temporary token being parsed
  txmlSentence s_cur;          //-- temporary sentence being parsed          
} txmlParseData;

//--------------------------------------------------------------
void txml_cb_start(txmlParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (strcmp(name,sElt)==0) {
    //-- s: parse relevant attribute(s)
    const XML_Char *s_id = get_attr(idAttr, attrs);
    if (s_id) {
      assert2((strlen(s_id) < TXML_ID_BUFLEN), "buffer overflow for s/@xml:id");
      strcpy(data->s_cur.s_id,s_id);
    } else {
      data->s_cur.s_id[0] = '\0';
    }
    data->w_cur.s_i = data->txd->s_len;
    txmlDataPushSentence(data->txd, &data->s_cur);
  }
  else if (strcmp(name,wElt)==0) {
    //-- w: parse relevant attribute(s)
    const XML_Char *w_id=NULL, *w_loc=NULL; //, *w_c=NULL
    char *w_loc_tail;
    ByteOffset w_i;
    int i;
    for (i=0; attrs[i] && (!w_id || !w_loc); i += 2) {
      if      (strcmp(attrs[i],  idAttr)==0) w_id =attrs[i+1];
      else if (strcmp(attrs[i], posAttr)==0) w_loc=attrs[i+1];
    }

    //-- w: populate token record
    if (w_id) {
      assert2((strlen(w_id) < TXML_ID_BUFLEN), "buffer overflow for w/@xml:id");
      strcpy(data->w_cur.w_id, w_id);
    } else {
      data->w_cur.w_id[0] = '\0';
    }

    //-- w: parse .txt location
    data->w_cur.w_txtoff = strtoul(w_loc,      &w_loc_tail, 0);
    data->w_cur.w_txtlen = strtoul(w_loc_tail, NULL,        0);

    //-- w: push token record
    w_i = data->txd->w_len;
    txmlDataPushToken(data->txd, &data->w_cur);

    //-- w: populate cxaux
    // + note that we don't actually parse the c-ids from the 'c' attribute
    // + rather, we iterate lookup in a handy index vector (txtb2cx->data[])
    // + advantage: O(1) lookup for each <c>, so O(length(w.text)) for each token <w>
    // + disadvantage: requires that our indices (.t.xml, .cx, .bx) are consistent with the input file (.char.xml)
    for (i=0; i < data->w_cur.w_txtlen; i++) {
      cxRecord *cx = txtb2cx.data[data->w_cur.w_txtoff+i];
      if (cx != NULL) {
	cxAuxRecord *cxa = &cxaux[ cx - cxdata.data ];
	cxa->w_i  = w_i;
	cxa->s_i  = data->w_cur.s_i;
	cxa->w_ok = 1;
      }
    }
  }
  return;
}

//--------------------------------------------------------------
/*
void txml_cb_end(txmlParseData *data, const XML_Char *name)
{
  return;
}
*/


//--------------------------------------------------------------
txmlData *txmlDataExpand(txmlData *txd)
{
  ByteOffset wi, si, i;
  txmlToken    *w;
  txmlSentence *s;
  cxRecord  *cx, *cx0, *cx1;
  cxAuxRecord *cxa, *cxa0, *cxa1;

  //-- mark token boundaries
  for (wi=0; wi < txd->w_len; wi++) {
    w = &txd->w_data[wi];

    //-- token-initial <c>
    for (i=0; i < w->w_txtlen && (cx0=txtb2cx.data[w->w_txtoff+i])==NULL; i++) ;
    if (cx0 != NULL) cxaux[cx0-cxdata.data].w_begin = 1;

    //-- token-final <c>
    for (i=w->w_txtlen; i>0 && (cx1=txtb2cx.data[w->w_txtoff+i-1])==NULL; i--) ;
    if (cx1 != NULL) cxaux[cx1-cxdata.data].w_end = 1;

    //-- sentence-initial, -final <w>
    if (wi==0 || w->s_i != (w-1)->s_i) {
      txd->s_data[w->s_i].w_first = w;
      if (wi > 0)
	txd->s_data[(w-1)->s_i].w_last = (w-1);
    }
  }

  //-- assign <s>-indices to cxaux records
  for (si=0; si < txd->s_len; si++) {
    s = &txd->s_data[si];
    assert(s->w_first != NULL);
    assert(s->w_last != NULL);
    for (i=s->w_first->w_txtoff; i < s->w_last->w_txtoff+s->w_last->w_txtlen; i++) {
      cx = txtb2cx.data[i];
      if (cx==NULL) continue;
      cxa = &cxaux[cx-cxdata.data];
      cxa->s_i  = si;
      cxa->s_ok = 1;
    }
  }

  return txd;
}

//--------------------------------------------------------------
txmlData *txmlDataLoad(txmlData *txd, FILE *f, const char *filename)
{
  XML_Parser xp;
  txmlParseData data;

  //-- maybe (re-)initialize indices
  if (txd==NULL || txd->s_data==NULL || txd->w_data==NULL) txd=txmlDataInit(txd,0,0);
  assert(f != NULL /* require .t.xml file */);
  assert(cxdata.data != NULL && cxdata.len > 0 /* require non-empty cx data */);
  assert(cxaux != NULL /* require cxaux data */);
  assert(txtb2cx.len > 0 /* require populated txtb2cx index */);

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  assert2((xp != NULL), "XML_ParserCreate() failed");
  XML_SetUserData(xp, &data);
  //XML_SetElementHandler(xp, (XML_StartElementHandler)txml_cb_start, (XML_EndElementHandler)txml_cb_end);
  XML_SetElementHandler(xp, (XML_StartElementHandler)txml_cb_start, (XML_EndElementHandler)NULL);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp  = xp;
  data.txd = txd;

  //-- parse XML
  expat_parse_file(xp, f, filename);
  XML_ParserFree(xp);

  return txmlDataExpand(txd);
}

/*======================================================================
 * Misc
 */
//-- (nothing here)

/*======================================================================
 * Utils: .char.xml file(s): buffering
 */

//--------------------------------------------------------------
char   *cxmlbuf = NULL;
size_t  cxmllen = 0;

//--------------------------------------------------------------
void cxmlBufferLoad(FILE *f)
{
  size_t nwanted = file_size(f);
  size_t nread   = file_slurp(f, &cxmlbuf, 0);
  assert2(nread==nwanted, "short slurp in cxmlBufferLoad()");
  cxmllen = nread;
}

//--------------------------------------------------------------
typedef struct {
  XML_Parser   xp;             //-- underlying expat parser
  const char  *srcname;        //-- source filename (for error messages)
  FILE        *f_out;          //-- output file
  int          text_depth;     //-- total text depth
  ByteOffset   cxi;            //-- index of next expected <c>
} cxmlParseData;

// CXML_CHECK_IDS : whether to perform consistency checks on .char.xml //c/@xml:id
#define CXML_CHECK_IDS 1

// CXML_CHECK_LOC : whether to perform consistency checks on .char.xml byte-offsets
#define CXML_CHECK_LOC 1

#if CXML_CHECK_IDS || CXML_CHECK_LOC
# define CXML_CHECK_START 1
#endif

//-- debug
#define CXML_S_INDENT  "\n"
#define CXML_S_OUTDENT "\n"
#define CXML_S_EXTRA_FMT  " seg=\"%d/%d\""
#define CXML_S_EXTRA_ARGS , s->s_seg, s->s_nsegs

#define CXML_INDENT_W  "\n"
#define CXML_OUTDENT_W "\n"

//--------------------------------------------------------------
void cxml_check_start(cxmlParseData *data, cxRecord *cx, const XML_Char **attrs)
{
#if CXML_CHECK_IDS
  const char *c_id, *cx_id;
#endif

#if CXML_CHECK_IDS
  //-- check for <c>-id mismatches
  c_id  = get_attr("xml:id",attrs);
  cx_id = cx->id && cx->id[0]=='$' ? NULL : cx->id;
  if ( (cx_id || c_id) && !(cx_id && c_id && strcmp(cx_id,c_id)==0) ) {
    fprintf(stderr, "%s: <c>-id mismatch in '%s' at line %d, column %d; byte %ld: expected '%s', got '%s'\n",
	    prog,
	    data->srcname,
	    XML_GetCurrentLineNumber(data->xp),
	    XML_GetCurrentColumnNumber(data->xp),
	    XML_GetCurrentByteIndex(data->xp),
	    (cx_id  ? cx_id : "(null)"),
	    (c_id   ? c_id  : "(null)"));
    exit(255);
  }
#endif

#if CXML_CHECK_LOC
  //-- check for <c> byte-offset mismatches
  if ( cx->xoff != XML_GetCurrentByteIndex(data->xp) ) {
    fprintf(stderr, "%s: <c>-offset mismatch in '%s' at line %d, column %d; id='%s'; expected offset %lu, got offset %ld\n",
	    prog,
	    data->srcname,
	    XML_GetCurrentLineNumber(data->xp),
	    XML_GetCurrentColumnNumber(data->xp),
	    (cx->id ? cx->id : "(null)"),
	    cx->xoff,
	    XML_GetCurrentByteIndex(data->xp));

  }
#endif

  return;
}

//--------------------------------------------------------------
void cxml_cb_start(cxmlParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  cxRecord    *cx;
  cxAuxRecord *cxa;
  txmlToken    *w=NULL;
  txmlSentence *s=NULL;

  if (data->text_depth && (strcmp(name,"c")==0 || strcmp(name,"lb")==0)) {
    cx  = &cxdata.data[data->cxi];
    cxa = &cxaux[data->cxi];

#if CXML_CHECK_START
    //-- consistency check(s)
    cxml_check_start(data, cx, attrs);
#endif

#if 0 /* CONTINUE HERE */
    //-- get token- & sentence-pointers
    if ( cxa->w_ok ) {
      w = &txmldata.w_data[cxa->w_i];
      s = &txmldata.s_data[w->s_i];
    } else {
      w = NULL;
      //s = s;
    }

    //-- check for sentence(-segment) BEGIN
    if (cxa->s_segBegin && s) {
      const char *fmt = CXML_S_INDENT "<s xml:id=\"%s\">" CXML_S_OUTDENT;
      s->s_seg++;
      if (s->s_nsegs > 1) {
	if      (s->s_seg==1)          { fmt=CXML_S_INDENT "<s part=\"I\" xml:id=\"%s\"" CXML_S_EXTRA_FMT ">" CXML_S_OUTDENT; }
	else if (s->s_seg==s->s_nsegs) { fmt=CXML_S_INDENT "<s part=\"M\" " REF_ATTR "=\"" REF_HASH "%s\"" CXML_S_EXTRA_FMT ">" CXML_S_OUTDENT; }
	else                           { fmt=CXML_S_INDENT "<s part=\"F\" " REF_ATTR "=\"" REF_HASH "%s\"" CXML_S_EXTRA_FMT ">" CXML_S_OUTDENT; }
      }
      fprintf(data->f_out, fmt, s->s_id CXML_S_EXTRA_ARGS);
    }

    //-- CONTINUE HERE
    XML_DefaultCurrent(data->xp);

    //-- check for sentence(-segment) END
    if (cxa->s_segEnd && s) {
      fprintf(data->f_out, CXML_S_INDENT "</s><!-- END %s" CXML_S_EXTRA_FMT " -->" CXML_S_OUTDENT, s->s_id CXML_S_EXTRA_ARGS);
    }
#endif

    return;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth++;
  }

  XML_DefaultCurrent(data->xp);
}

//--------------------------------------------------------------
void cxml_cb_end(cxmlParseData *data, const XML_Char *name)
{
  if (data->text_depth && (strcmp(name,"c")==0 || strcmp(name,"lb")==0)) {
    data->cxi++;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth--;
  }
  XML_DefaultCurrent(data->xp);
}

//--------------------------------------------------------------
void cxml_cb_default(cxmlParseData *data, const XML_Char *s, int len)
{
  int ctx_len;
  const XML_Char *ctx = get_event_context(data->xp, &ctx_len);
  fwrite(ctx, sizeof(XML_Char),ctx_len, data->f_out);
}

//--------------------------------------------------------------
void cxmlBufferParse(const char *filename, FILE *f_out)
{
  cxmlParseData data;
  XML_Parser xp;

  //-- sanity checks
  assert(cxmlbuf != NULL);
  assert(cxmllen > 0);

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  assert2((xp != NULL), "XML_ParserCreate() failed");
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cxml_cb_start, (XML_EndElementHandler)cxml_cb_end);
  //XML_SetCharacterDataHandler(xp, (XML_CharacterDataHandler)cxml_cb_char);
  XML_SetDefaultHandler(xp, (XML_DefaultHandler)cxml_cb_default);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp = xp;
  data.srcname = filename;
  data.f_out = f_out;

  //-- parse
  expat_parse_string(xp, cxmlbuf, (int)cxmllen, filename);

  //-- cleanup
  XML_ParserFree(xp);
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  char *filename_txml = "-";
  char *filename_cxml = NULL;
  char *filename_cx   = NULL;
  char *filename_bx   = NULL;
  char *filename_out  = "-";
  char *xmlsuff = "";    //-- additional suffix for root @xml:base
  FILE *f_txml = stdin;   //-- input .t.xml file
  FILE *f_cxml = NULL;    //-- input .char.xml file
  FILE *f_cx   = NULL;    //-- input .cx file
  FILE *f_bx   = NULL;    //-- input .bx file
  FILE *f_out  = stdout;  //-- output .char.sw.xml file
  int i;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 4) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s TXMLFILE CXMLFILE CXFILE BXFILE [OUTFILE]\n", prog);
    fprintf(stderr, " + TXMLFILE : xml tokenizer output as created by dtatw-tok2xml\n");
    fprintf(stderr, " + CXMLFILE : base-format .chr.xml input file\n");
    fprintf(stderr, " + CXFILE   : character index file as created by dtatw-mkindex\n");
    fprintf(stderr, " + BXFILE   : block index file as created by dta-tokwrap.perl\n");
    fprintf(stderr, " + OUTFILE  : output XML file (default=stdout)\n");
    fprintf(stderr, " + \"-\" may be used in place of any filename to indicate standard (in|out)put\n");
    exit(1);
  }

  //-- command-line: .t.xml file
  if (argc > 1) {
    filename_txml = argv[1];
    if (strcmp(filename_txml,"-")==0) f_txml = stdin;
    else if ( !(f_txml=fopen(filename_txml,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .t.xml file `%s': %s\n", prog, filename_txml, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .char.xml file
  if (argc > 2) {
    filename_cxml = argv[2];
    if (strcmp(filename_cxml,"-")==0) f_cxml = stdin;
    else if ( !(f_cxml=fopen(filename_cxml,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cxml, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .cx file
  if (argc > 3) {
    filename_cx = argv[3];
    if (strcmp(filename_cx,"-")==0) f_cx = stdin;
    else if ( !(f_cx=fopen(filename_cx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .bx file
  if (argc > 4) {
    filename_bx = argv[4];
    if (strcmp(filename_bx,"-")==0) f_bx = stdin;
    else if ( !(f_bx=fopen(filename_bx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .bx file `%s': %s\n", prog, filename_bx, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: output file
  if (argc > 5) {
    filename_out = argv[5];
    if (strcmp(filename_out,"")==0) f_out = NULL;
    else if ( strcmp(filename_out,"-")==0 ) f_out = stdout;
    else if ( !(f_out=fopen(filename_out,"wb")) ) {
      fprintf(stderr, "%s: open failed for output XML file `%s': %s\n", prog, filename_out, strerror(errno));
      exit(1);
    }
  }
  assert2(f_out!=NULL, "output file required");

  //-- load .cx data
  cxDataLoad(&cxdata, f_cx);
  fclose(f_cx);
  f_cx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: loaded %6lu records from .cx file '%s'\n", prog, cxdata.len, filename_cx);
#endif

  //-- load .bx data
  bxDataLoad(&bxdata, f_bx);
  if (f_bx != stdin) fclose(f_bx);
  f_bx = NULL;

#ifdef VERBOSE_IO
  fprintf(stderr, "%s: loaded %6lu records from .bx file '%s'\n", prog, bxdata.len, filename_bx);
#endif
  
  //-- create (tx_byte_index => cx_record) lookup vector
  tx2cxIndex(&txb2cx, &cxdata);
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: initialized %6lu-element .tx-byte => .cx-record index\n", prog, txb2cx.len);
#endif

  //-- create (txt_byte_index => cx_record_or_NULL) lookup vector
 txt2cxIndex(&txtb2cx, &bxdata, &txb2cx);
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: initialized %6lu-element .txt-byte => .cx-record index\n", prog, txtb2cx.len);
#endif

  //-- allocate (c_index => cxAuxRecord) lookup vector
  cxaux = (cxAuxRecord*)malloc(cxdata.len*sizeof(cxAuxRecord));
  assert2( (cxaux!=NULL), "malloc failed");
  memset(cxaux, 0, cxdata.len*sizeof(cxAuxRecord)); //-- ... and zero the block
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: allocated %6lu-element auxilliary .cx-record index\n", prog, cxdata.len);
#endif

  //-- load .t.xml data (expat)
  txmlDataLoad(&txmldata, f_txml, filename_txml);
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu tokens in %lu sentences from .t.xml file '%s'\n", prog, txmldata.w_len, txmldata.s_len, filename_txml);
#endif

  //-- load .char.xml file into buffer (and parse it)
  cxmlBufferLoad(f_cxml);
  cxmlBufferParse(filename_cxml, f_out);
#if VERBOSE_IO
  fprintf(stderr, "%s: buffered & parsed %lu XML bytes from .char.xml file '%s'\n", prog, cxmllen, filename_cxml);
#endif

  //-- CONTINUE HERE: NOW WHAT ?!

  //-- cleanup
  if (f_txml && f_txml != stdin) fclose(f_txml);
  if (f_cxml && f_cxml != stdin) fclose(f_cxml);
  if (f_cx   && f_cx   != stdin) fclose(f_cx);
  if (f_bx   && f_bx   != stdin) fclose(f_bx);
  if (f_out  && f_out  != stdout) fclose(f_out);

  return 0;
}