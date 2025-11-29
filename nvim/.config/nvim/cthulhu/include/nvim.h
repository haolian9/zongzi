#include <stdbool.h>
#include <stdint.h>
#include <time.h>

typedef void *buf_T;
buf_T *buflist_findnr(int nr);
char *ml_get_buf(buf_T *buf, int32_t lnum, bool will_change);

extern int msg_silent;  // don't print messages
extern int emsg_silent; // don't print error messages
extern bool cmd_silent; // don't echo the command line

typedef void *HlMessage;
/// Message history for `:messages`
typedef struct msg_hist {
  struct msg_hist *next;  ///< Next message.
  struct msg_hist *prev;  ///< Previous message.
  time_t time;            ///< message occurred time
  HlMessage msg;          ///< Highlighted message.
  const char *kind;       ///< Message kind (for msg_ext)
  bool temp;              ///< Temporary message since last command ("g<")
} MessageHistoryEntry;
extern MessageHistoryEntry *msg_hist_last;
