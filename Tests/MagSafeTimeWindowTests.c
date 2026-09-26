#include <assert.h>
#include <stdio.h>
#include "../Tools/LEDTimeWindow.h"
int main(void) {
    assert(!ledWindowContains(1319, 1320, 480));
    assert(ledWindowContains(1320, 1320, 480));
    assert(ledWindowContains(1439, 1320, 480));
    assert(ledWindowContains(0, 1320, 480));
    assert(ledWindowContains(479, 1320, 480));
    assert(!ledWindowContains(480, 1320, 480));
    assert(!ledWindowContains(599, 600, 720));
    assert(ledWindowContains(600, 600, 720));
    assert(!ledWindowContains(720, 600, 720));
    assert(ledWindowContains(900, 0, 0));
    assert(!ledWindowContains(1440, 0, 0));
    assert(!ledWindowContains(0, -1, 60));
    puts("MagSafe daily schedule: 12 boundary and overnight assertions passed.");
}
