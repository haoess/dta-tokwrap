#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_out;          //-- output file
} ParseData;

//-- indentation/formatting
const char *indent_w = "\n  ";
const char *indent_c = "\n    ";
const char *indent_root = "\n";

#define WANT_T_ATTR 1

/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(ParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  int i;
  const XML_Char *xml_id=NULL, *ca=NULL,*c_begin,*c_end, *ta=NULL;
  if (strcmp(name,"w")!=0) return;
  fprintf(data->f_out, "%s<w", indent_w);
  for (i=0; attrs[i] && (!xml_id || !ca || !ta); i += 2) {
    if      (strcmp(attrs[i],"xml:id")==0) xml_id=attrs[i+1];
    else if (strcmp(attrs[i],"c")==0)          ca=attrs[i+1];
#ifdef WANT_T_ATTR
    else if (strcmp(attrs[i],"t")==0)          ta=attrs[i+1];
#endif
  }
  if (xml_id) {
    fputs(" xml:id=\"", data->f_out);
    put_escaped_str(data->f_out, xml_id, -1);
    fputc('"', data->f_out);
  }
#ifdef WANT_T_ATTR
  if (ta) {
    fputs(" t=\"", data->f_out);
    put_escaped_str(data->f_out, ta, -1);
    fputc('"', data->f_out);
  }
#endif
  fputc('>', data->f_out);
  if (ca) {
    for (c_begin=ca; *c_begin; c_begin=c_end) {
      for ( ; *c_begin && isspace(*c_begin); c_begin++) {
	;
      }
      for (c_end=c_begin; *c_end && !isspace(*c_end); c_end++) {
	;
      }
      if (*c_begin && c_end > c_begin) {
	fputs(indent_c,data->f_out);
	fputs("<c ref=\"#", data->f_out);
	put_escaped_str(data->f_out, c_begin, c_end-c_begin);
	fputs("\"/>", data->f_out);
      }
    }
  }
  fputs(indent_w, data->f_out);
  fputs("</w>", data->f_out);
}

//--------------------------------------------------------------
void cb_end(ParseData *data, const XML_Char *name)
{
  return;
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  ParseData data;
  XML_Parser xp;
  char *filename_in  = "-";
  char *filename_out = "-";
  char *xmlbase = "", *xmlsuff="";
  FILE *f_in  = stdin;   //-- input file
  FILE *f_out = stdout;  //-- output file
  int i;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s INFILE [OUTFILE [XMLBASE]]\n", prog);
    fprintf(stderr, " + INFILE  : XML-ified tokenizer output file\n");
    fprintf(stderr, " + OUTFILE : token-level standoff XML file\n");
    fprintf(stderr, " + XMLBASE : xml:base attribute for output file\n");
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
  //-- command-line: output file
  if (argc > 2) {
    filename_out = argv[2];
    if (strcmp(filename_out,"")==0) {
      f_out = NULL;
    }
    else if ( strcmp(filename_out,"-")==0 ) {
      f_out = stdout;
    }
    else if ( !(f_out=fopen(filename_out,"wb")) ) {
      fprintf(stderr, "%s: open failed for output file `%s': %s\n", prog, filename_out, strerror(errno));
      exit(1);
    }
  }
  if (argc > 3) {
    xmlbase = argv[3];
    xmlsuff = "";
  } else if (filename_in && strcmp(filename_in,"-") != 0) {
    xmlbase = file_basename(NULL, filename_in, ".t.xml", -1,0);
    xmlsuff = ".xml";
  } else {
    //-- last-ditch effort
    xmlbase = filename_in;
    xmlsuff = "";
  }

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  if (!xp) {
    fprintf(stderr, "%s: XML_ParserCreate failed", prog);
    exit(1);
  }
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp    = xp;
  data.f_out = f_out;

  //-- print header
  fprintf(f_out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  //--
  fprintf(f_out, "<!--\n");
  fprintf(f_out, " ! File created by %s (%s version %s)\n", prog, PACKAGE, PACKAGE_VERSION);
  fprintf(f_out, " ! Command-line: %s", argv[0]);
  for (i=1; i < argc; i++) {
    fprintf(f_out, " '%s'", (argv[i][0] ? argv[i] : ""));
  }
  fprintf(f_out, "\n !-->\n");
  //--
  fprintf(f_out, "<tokens xml:base=\"%s%s\">", xmlbase, xmlsuff);

  //-- parse input file
  expat_parse_file(xp, f_in, filename_in);

  //-- print footer
  fprintf(f_out, "%s</tokens>\n", indent_root);

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_out) fclose(f_out);
  if (xp) XML_ParserFree(xp);

  return 0;
}