#ifndef LED_TIME_WINDOW_H
#define LED_TIME_WINDOW_H
// Equal endpoints mean all day; start inclusive, end exclusive.
static int ledWindowContains(int minute, int start, int end) {
    if (minute < 0 || minute >= 1440 || start < 0 || start >= 1440 || end < 0 || end >= 1440) return 0;
    return start == end || (start < end ? minute >= start && minute < end : minute >= start || minute < end);
}
#endif
