/*
EXECUTION
 */
// called each (#define PERIOD)
void execution()
{
  int d;
  for(d=0; d<NB_DEV; d++){
    switch(RUN[d]){
    case STOP :
      {
        switch_DEV_stop(d);
        break;
      }
    case AUTO :
      {
        if (DEV[d] != STEPPER) {
          do_ramp(d);
          switch_DEV_run(d);
        } 
        else {
          do_step(d);
          switch_DEV_run(d);
        }
        break;
      }
    case CONTROL :
      {
        // do nothing here. see in setDEV at 'v' command. 
        break;
      }
    }
  }
}

/*
INFORMATION
 */
// called each 5*(#define PERIOD)
void info(int d)
{
  if(INFO[d]){
    if(RUN[d]){
      // return the value to the user
      Serial.print("/");
      Serial.print(d,DEC);
      Serial.print(" v ");
      Serial.println(int(A_VALUE[d]),DEC);

      // return the time to the user
      Serial.print("/");
      Serial.print(d,DEC);
      Serial.print(" T ");
      Serial.println(int(A_TIME[d]),DEC);
    }
  }  
}

/*
ANALOGIC INPUTS
 */
void analogic()
{
  short pin;
  int val;

  Serial.print("/A d ");
  for(pin = 0; pin < 6; pin++){
    val = 0;
    val = analogRead(pin);
    Serial.print(val,DEC);
    Serial.print(" ");
  }
  Serial.println();
} 

void switch_DEV_run(int d)
{
  switch(DEV[d]){
  case DC :
    {
      DC_run(d);
      break;
    }
  case SERVO :
    {
      SERVO_run(d);
      break;
    }
  case STEPPER :
    {
      STEPPER_run(d);
      break;
    }
  }
}

void switch_DEV_stop(int d)
{
  switch(DEV[d]){ 
  case DC :
    {
      DC_stop(d);
      break;
    }
  case SERVO :
    {
      SERVO_stop(d);
      break;
    }
  case STEPPER :
    {
      STEPPER_stop(d);
      break;
    }
  } 
}

void do_ramp(int d)
{
  A_DATE[d] += PERIOD;
  A_TIME[d] += PERIOD;

  // ramp the value
  A_VALUE[d] += A_RAMP[d]*PERIOD;
  if(A_VALUE[d] < 0.) A_VALUE[d] = 0.;
  if(A_VALUE[d] > 255.) A_VALUE[d] = 255.;

  // When A_DATE[d] overflow : calculate the ramp to interpolate A_DATA[p] / A_DATA[p+1]
  if(A_DATE[d] >= TIME[d][A_INDEX[d]] * TIMECODE){
    A_DATE[d] = 0;
    A_VALUE[d] = float(VALUE[d][A_INDEX[d]]);
    A_INDEX[d]++;
    if(A_INDEX[d] >= NB_PTS[d]){
      A_RAMP[d] = float(VALUE[d][0] - VALUE[d][NB_PTS[d]-1]) / float(TIMELOOP);
      A_INDEX[d] = 0;
      A_TIME[d] = 0;
    }
    else{
      A_RAMP[d] = float(VALUE[d][A_INDEX[d]] - VALUE[d][A_INDEX[d]-1]) / float(TIME[d][A_INDEX[d]] * TIMECODE);
    }
  }
}

void do_step(int d)
{
  A_DATE[d] += PERIOD;
  A_TIME[d] += PERIOD;

  // do nothing
  A_VALUE[d] = 127;

  // When A_DATE[d] overflow : set A_VALUE[d] to the next step to go
  if(A_DATE[d] >= TIME[d][A_INDEX[d]] * TIMECODE){
    A_DATE[d] = 0;
    A_VALUE[d] = float(VALUE[d][A_INDEX[d]]);
    A_INDEX[d]++;

    if(A_INDEX[d] >= NB_PTS[d]){
      A_INDEX[d] = 0;
      A_TIME[d] = 0;
    }
  }
}

void DC_run(int d)
{
  if (RUN[d]) {
    int v = int(A_VALUE[d]);
    int spd;
    byte dir;

    if(v < 127){
      spd = (127 - v) * 2;
      dir = BACKWARD;
    }
    if(v == 127){
      spd = 0;
      dir = RELEASE;
    }
    if(v > 127){
      spd = (v - 127) * 2 - 1;
      dir = FORWARD;
    }
    switch(d){
    case 0 :
      {
        DC1.setSpeed(spd);
        DC1.run(dir);
        break;
      }
    case 1 :
      {
        DC2.setSpeed(spd);
        DC2.run(dir);
        break;
      }
    case 2 :
      {
        DC3.setSpeed(spd);
        DC3.run(dir);
        break;
      }
    case 3 :
      {
        DC4.setSpeed(spd);
        DC4.run(dir);
        break;
      }
    }
  }
}

void DC_stop(int d)
{
  switch(d){
  case 0 :
    {
      DC1.run(RELEASE);
      break;
    }
  case 1 :
    {
      DC2.run(RELEASE);
      break;
    }
  case 2 :
    {
      DC3.run(RELEASE);
      break;
    }
  case 3 :
    {
      DC4.run(RELEASE);
      break;
    }
  }
}

void SERVO_run(int d)
{
  if (RUN[d]) {
    byte angle;
    angle = map(A_VALUE[d], 0, 255, 0, 180);
    switch(d){
    case 4 :
      {
        SERVO1.write(angle);
        break;
      }
    case 5 :
      {
        SERVO2.write(angle);
        break;
      }
    }
  }
}

void SERVO_stop(int d){
  switch(d){
  case 4 :
    {
      SERVO1.write(93);
      break;
    }
  case 5 :
    {
      SERVO2.write(97);
      break;
    }
  }
}

void STEPPER_run(int d)
{
  if (RUN[d]) {
    int v = int(A_VALUE[d]);
    int stp;
    byte dir;

    if(v < 127){
      stp = (127 - v) * 2;
      dir = BACKWARD;
    }
    if(v == 127){
      return;
    }
    if(v > 127){
      stp = (v - 127) * 2 - 1;
      dir = FORWARD;
    }
    switch(d){
    case 6 :
      {
        STEPPER1.step(stp, dir, SINGLE); // TODO : choisir le type de progression (SINGLE, DOUBLE, INTERLEAVE, MICROSTEP)
        break;
      }
    case 7 :
      {
        STEPPER2.step(stp, dir, SINGLE); // TODO : choisir le type de progression (SINGLE, DOUBLE, INTERLEAVE, MICROSTEP)
        break;
      }
    }
  }
}

void STEPPER_stop(int d){
  switch(d){
  case 6 :
    {
      //STEPPER1.step(0, FORWARD, SINGLE);
      break;
    }
  case 7 :
    {
      //STEPPER2.step(0, FORWARD, SINGLE);
      break;
    }
  }
}




