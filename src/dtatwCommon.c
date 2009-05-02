#include <dtatwCommon.h>

char *prog = "dtatwCommon"; //-- used for error reporting

//----------------------------------------------------------------------
ByteOffset expat_parse_file(XML_Parser xp, FILE *f_in, const char *filename_in) 
{
  ByteOffset n_xbytes=0;
  size_t nread;
  int status, is_final = 0;
  do {
    //-- setup & read into buffer (uses expat functions to avoid double-copy)
    void *buf = XML_GetBuffer(xp, FILE_BUFSIZE);
    if (!buf) {
      fprintf(stderr, "%s: XML_GetBuffer() failed!\n", prog);
      exit(1);
    }
    nread = fread(buf, 1,FILE_BUFSIZE, f_in);
    n_xbytes += nread;

    //-- check for file errors
    is_final = feof(f_in);
    if (ferror(f_in) && !is_final) {
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): I/O error: %s\n",
	      prog, filename_in,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      strerror(errno));
      exit(2);
    }

    status = XML_ParseBuffer(xp, (int)nread, is_final);

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
      exit(3);
    }
  } while (!is_final);
  return n_xbytes;
}
