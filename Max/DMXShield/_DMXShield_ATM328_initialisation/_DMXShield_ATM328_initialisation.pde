/*
 _DMXShield_ATM328_initialisation.pde
 
 pour initialiser l'EEPROM d'une arduino avec un AtMega328 et DMXShield
 afin de controller jusqu'à 8 canaux DMX
 
 */

#include <EEPROM.h>

// Define
//////////

// DEVICES
#define NB_DEV 8 // how many channel to control
#define DMX 0 // DMX channel type id

// DATA
#define NB_PTS_MAX 60 // a point is a value and a ramp time
// 60*8*2 = 960 bytes / 1000 bytes in EEPROM.
// the first 32 bytes are for other informations
#define _PRESET 0 // adress of the id of the saved preset
#define _TIMER 1 // adress where the timer period is stored
#define _ANALOG_TIMER 2 // adress where the analogic timer period is stored
#define _DEV 10 // adress where the type of each device is stored (10,11,...,19)
#define _NB_PTS 20 // adress where the nb points of each array is stored (20,21,...,29)
#define _DATA 33 //adress where datas start

void setup()
{
  // COMMUNICATION
  Serial.begin(115200);

  // DATA
  setEEPROM();
}

void loop() {
}

void setEEPROM()
{
  int d, p;
  EEPROM.write(_TIMER,10);
  delay(5);
  EEPROM.write(_PRESET,1);
  delay(5);
  EEPROM.write(_ANALOG_TIMER,10);
  delay(5);
  for(d=0; d<NB_DEV; d++)
  {
    EEPROM.write(_DEV + d, DMX);

    delay(5);
    EEPROM.write(_NB_PTS + d, 1);
    delay(5);

    // a first commande (127, 0)
    p=0;
    EEPROM.write(_DATA + 2*d*NB_PTS_MAX + 2*p, byte(127));
    delay(5);
    EEPROM.write(_DATA + 2*d*NB_PTS_MAX + (2*p)+1, byte(0));
    delay(5);

    // and then nothing (0, 0)
    for(p=1; p<NB_PTS_MAX; p++) {
      EEPROM.write(_DATA + 2*d*NB_PTS_MAX + 2*p, byte(0));
      delay(5);
      EEPROM.write(_DATA + 2*d*NB_PTS_MAX + (2*p)+1, byte(0));
      delay(5);
    }
  }
  
  Serial.println(":E done");
}

