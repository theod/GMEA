/*
 _AFMotorShield_ATM328.pde
 
 pour programmer une arduino avec un AtMega328 et MotorShield Adafruit
 afin de controller jusqu'à 4 moteurs DC + 2 servo
 
 */

#include <EEPROM.h>
#include <Servo.h>
#include <AFMotor.h>

// Define
//////////

#define VERSION "DC_SERVO_STEPPER_328 (v0.2)"

// DEVICES
#define NB_DEV 8 // how many device to control
#define DC 0 // DC Motor device type id
#define SERVO 1 // SERVO Motor device type id
#define STEPPER 2 // STEPPER Motor device type id

// DC1:0, DC2:1, DC3:2, DC4:3
// SERVO1:4, SERVO2:5
// STEPPER1:6, STEPPER2:7

#define SERVO1Pin 9
#define SERVO2Pin 10

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

// TIMER
#define TIMECODE 50 // time unit to convert byte data [0::255] in ms (here [0ms ::50*255 = 12750 ms])
#define TIMELOOP 0 // time (in ms) to ramp the value from the last value to the first (here 0 ms)

// COMMUNICATION
#define MAX_CMD_SIZE 8
#define NONE 0
#define GET 1
#define SET 2
#define RxPin 0 // receive data from pin 0 (Rx)

#define STOP 0
#define AUTO 1
#define CONTROL 2

// Declaration
///////////////

// DEVICES

AF_DCMotor DC1(1, MOTOR12_2KHZ);
AF_DCMotor DC2(2, MOTOR12_2KHZ);
AF_DCMotor DC3(3, MOTOR34_64KHZ);
AF_DCMotor DC4(4, MOTOR34_64KHZ);

Servo SERVO1;
Servo SERVO2;

AF_Stepper STEPPER1(200, 1);    // le nombre de pas dépend du moteur controllé
AF_Stepper STEPPER2(400, 2);    // le nombre de pas dépend du moteur controllé

// DATA
byte Preset; //id of the loaded preset from EEPROM (0 means no Preset saved in EEPROM)
byte DEV[NB_DEV]; // store device type for each device
byte VALUE[NB_DEV][NB_PTS_MAX]; // store value for each device
byte TIME[NB_DEV][NB_PTS_MAX]; // store ramp time for each device
byte NB_PTS[NB_DEV]; // nb points stored for each device
byte RUN[NB_DEV]; // run state for each device
boolean INFO[NB_DEV]; // info state for each device (0 : don't output info)
int A_DATE[NB_DEV]; // actual time used to ramp value for each device
int A_TIME[NB_DEV]; // actual time in the loop for each device in ms
byte A_INDEX[NB_DEV]; // actual point for each device
float A_RAMP[NB_DEV]; // actual Inc/dec to do at each execution to interpolate each A_value
float A_VALUE[NB_DEV]; // actual value to control each device

// TIMER
byte PERIOD; // the timer period to execute devices (ms)
unsigned long lastExec;
unsigned long lastInfo;
unsigned long lastAnalog;
byte lastId; // id of the last device

// ANALOG IN
byte ANALOG_PERIOD; // the timer period to capture analogic inputs (ms)
boolean ANALOG_IO; // IO the reading of analogic inputs

// COMMUNICATION
byte Cmd[MAX_CMD_SIZE]; //Command read on the Rx pin
byte sizeCmd; 
byte typeCmd; //Command flag (NONE, GET, SET)

void setup()
{
  // COMMUNICATION
  Serial.begin(115200);
  sizeCmd = 0;
  typeCmd = NONE;
  
  // VERSION
  getVersion();

  // DATA
  getEEPROM();

  // TIMER
  lastExec = 0;
  lastInfo = 0;
  lastAnalog = 0;
  lastId = 0;

  // DEVICES
  DC1.setSpeed(0);
  DC2.setSpeed(0);
  DC3.setSpeed(0);
  DC4.setSpeed(0);

  SERVO1.attach(SERVO1Pin);
  SERVO2.attach(SERVO2Pin);
  
  STEPPER1.setSpeed(50); // M1 M2
  STEPPER2.setSpeed(25); // M3 M4
  
  // ANALOGIC INPUTS
  ANALOG_PERIOD = 10;
  ANALOG_IO = false;
}

void loop()
{
  unsigned long mils;
  
  // TIMER
  if(PERIOD){
    mils = millis();
    if(mils - lastExec > PERIOD){
      lastExec = mils;
      execution();
    }
    
    if(mils - lastInfo > (PERIOD*5)){
      lastInfo = mils;
      info(lastId);
      lastId++;
      if(lastId >= NB_DEV) lastId = 0;
    }
  }
  
  // ANALOGIC TIMER
  if(ANALOG_PERIOD && ANALOG_IO){
    mils = millis();
      if(mils - lastAnalog > ANALOG_PERIOD){
        lastAnalog = mils;
        analogic();
    }
  }

  // COMMUNICATION
  if(!typeCmd){ 
    sizeCmd = checkCommand();
  }
  else{
    switchCommand();
    typeCmd = NONE;
  }
 
  // SCENARIO
  SCENARIO();
}

// load data from EEPROM in SDRAM
void getEEPROM()
{
  int d,p;
  Preset = EEPROM.read(_PRESET);
  PERIOD = EEPROM.read(_TIMER);
  ANALOG_PERIOD = EEPROM.read(_ANALOG_TIMER);
  if(Preset){
    for(d=0; d<NB_DEV; d++)
    {
      DEV[d] = EEPROM.read(_DEV + d);
      NB_PTS[d] = EEPROM.read(_NB_PTS + d);
      for(p=0; p<NB_PTS[d]; p++){
        VALUE[d][p] = EEPROM.read(_DATA + 2*d*NB_PTS_MAX + 2*p);
        TIME[d][p] = EEPROM.read(_DATA + 2*d*NB_PTS_MAX + (2*p)+1);
        if((PERIOD != 0)&&(NB_PTS[d] > 0)) RUN[d] = AUTO;
        else RUN[d] = STOP;
        INFO[d] = false;
      }
    }
    Serial.println("?E done");
  }
}

// save data from SDRAM in EEPROM
void setEEPROM()
{
  int d, p;
  if(Preset){
    EEPROM.write(_TIMER,PERIOD);
    delay(5);
    EEPROM.write(_PRESET,Preset);
    delay(5);
    EEPROM.write(_ANALOG_TIMER, ANALOG_PERIOD);
    delay(5);
    for(d=0; d<NB_DEV; d++)
    {
      EEPROM.write(_DEV + d, DEV[d]);
      delay(5);
      EEPROM.write(_NB_PTS + d, NB_PTS[d]);
      delay(5);
      for(p=0; p<NB_PTS[d]; p++){
        EEPROM.write(_DATA + 2*d*NB_PTS_MAX + 2*p, byte(VALUE[d][p]));
        delay(5);
        EEPROM.write(_DATA + 2*d*NB_PTS_MAX + (2*p)+1, byte(TIME[d][p]));
        delay(5);
      }
    }
    Serial.println(":E done");
  }
}
