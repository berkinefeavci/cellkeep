#include <assert.h>
#include <stdio.h>
#include "../Tools/LEDControllers.h"
int main(void) {
    assert(isOtherControllerName("AlDente"));
    assert(isOtherControllerName("AlDenteHelper"));
    assert(isOtherControllerName("me.mhaeuser.batterytoolkitd"));
    assert(isOtherControllerName("BatFi"));
    assert(isOtherControllerName("software.micropixels.BatFi.Help"));
    assert(isOtherControllerName("batt"));
    assert(!isOtherControllerName("battery"));
    assert(!isOtherControllerName("batterydaemon"));
    assert(!isOtherControllerName("Cellkeep"));
    assert(!isOtherControllerName(""));
    puts("LED helper controllers: 10 name assertions passed.");
}
