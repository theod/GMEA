/*
SERIAL COMMUNICATION
 */
int checkCommand()
{
  boolean go = false;
  int i=0;
  int j=0;
  int k=0;
  int RxValue;
  int c[5] = {0,0,0,0,0};
  int d=1;
  int n;

  if(Serial.available() > 0){
    RxValue = Serial.read();
    if(RxValue == '?'){
      typeCmd = GET;
      go = true;
    }
    if(RxValue == ':'){
      typeCmd = SET;
      go = true;
    }
    while(go){
      if(Serial.available() > 0){
        RxValue = Serial.read();
        go = RxValue != 13; // to stop while
        // build number
        if((RxValue >= 48)&&(RxValue <= 57)&&(j<5)){
          c[j] = RxValue - 48;
          d *= 10;
          j++;
          continue;
        }
        if((RxValue == 32)||(RxValue == 13)){
          n = 0;
          if(j>0){
            for(k=0;k<j;k++){
              d /= 10;
              n += c[k]*d;
            }
            j = 0;
            Cmd[i] = n;
            i++;
          }
          continue;
        }
        else{
          Cmd[i] = RxValue;
          i++;
        }
      }
    }
  }
  return i;
}

void switchCommand()
{
  switch(typeCmd){
  case GET :
    {
      switch(Cmd[0]){
      case 'P':
        {
          getPreset();
          break;
        }
      case 'T':
        {
          getTimer();
          break;
        }
      case 'E':
        {
          getEEPROM();
          break;
        }
      case 'A':
        {
          getAnalogIO();
          break;
        }
      case 'V':
        {
          getVersion();
          break;
        }
      default:
        {
          if(Cmd[0] < NB_DEV){
            getDEV(Cmd[0]);
          }
          break; 
        }
      }
      break;
    }
  case SET :
    {
      switch(Cmd[0]){
      case 'P':
        {
          setPreset();
          break;
        }
      case 'T':
        {
          setTimer();
          break;
        }
      case 'E':
        {
          setEEPROM();
          break;
        }
      case 'A':
        {
          setAnalogIO();
          break;
        }
      default:
        {
          if(Cmd[0] < NB_DEV){
            setDEV(Cmd[0]);
          }
          break; 
        }
      }
      break;
    }
  }
}

void getPreset()
{
  Serial.print("/P ");
  Serial.println(Preset,DEC);
}

void setPreset()
{
  if(sizeCmd == 2){
    Preset = int(Cmd[1]);
  }
}

void getDEV(int d)
{
  int p;
  switch(Cmd[1]){
  case 't' : 
    { // to get the type of the device
      if(sizeCmd == 2){
        Serial.print("/");
        Serial.print(d,DEC);
        Serial.print(" t ");
        if(DEV[d] == DC) Serial.println("DC");
        if(DEV[d] == SERVO) Serial.println("SERVO");
        if(DEV[d] == STEPPER) Serial.println("STEPPER");
      }
      break;
    }
  case 'd' :
    { // to get data
      for(p=0; p<NB_PTS[d]; p++){
        Serial.print("/");
        Serial.print(d,DEC);
        Serial.print(" d ");
        Serial.print(VALUE[d][p],DEC);  
        Serial.print(" ");
        Serial.println(TIME[d][p],DEC);
      }
      Serial.print("/");
      Serial.print(d,DEC);
      Serial.print(" d ");
      Serial.println("done");
      break;
    }
  case 'r' : 
    { // to get run mode of a device
      if(sizeCmd == 2){
        Serial.print("/");
        Serial.print(d,DEC);
        Serial.print(" r ");
        Serial.println(RUN[d],DEC);
      }
      break;
    }
  case 'i' : 
    { // to get info mode of a device
      if(sizeCmd == 2){
        Serial.print("/");
        Serial.print(d,DEC);
        Serial.print(" i ");
        if(INFO[d]){
          Serial.println(1,DEC);
        }
        else{
          Serial.println(0,DEC);
        }
      }
      break;
    }
  }
}

void setDEV(int d)
{
  int p;
  switch(Cmd[1]){
  case 't' : 
    { // to set the type of the device
      if(sizeCmd == 3){
        DEV[d] = Cmd[2];
      }
      break;
    }
  case 'd' :
    { // to set data
      if((NB_PTS[d] < NB_PTS_MAX)&&(sizeCmd == 4)){
        VALUE[d][NB_PTS[d]] = Cmd[2];
        TIME[d][NB_PTS[d]] = Cmd[3];
        NB_PTS[d]++;
        A_TIME[d] = 0;
      }
      break;
    }
  case 'r' : 
    { // to set IO the run mode of the device
      if(sizeCmd == 3){
        RUN[d] = Cmd[2];
      }
      break;
    }
  case 'i' : 
    { // to set IO the info mode of the device
      if(sizeCmd == 3){
        INFO[d] = Cmd[2] > 0;
      }
      break;
    }
  case 'v' : 
    { // to control the device directly
      if((sizeCmd == 3)&&(RUN[d] == CONTROL)){
        A_VALUE[d] = Cmd[2];
        switch_DEV_run(d);
      }
      break;
    }
  case 'c' :
    { // to clear all RAM data about a device
      for(p=0; p<NB_PTS_MAX; p++){
        VALUE[d][p] = 0;
        TIME[d][p] = 0;
      }
      NB_PTS[d] = 0;
      RUN[d] = false;
      A_DATE[d] = 0;
      A_INDEX[d] = 0;
      A_RAMP[d] = 0.;
      A_VALUE[d] = 0.; // ??? TODO : a start value ?
      break;
    }
  }  
}

void getTimer()
{
  Serial.print("/T ");
  Serial.println(PERIOD,DEC);
}

void setTimer()
{
  if(sizeCmd == 2){
    if(Cmd[1] > 0)
      PERIOD = Cmd[1];
    else
      PERIOD = 1;
  }
}

void getAnalogIO()
{
  switch(Cmd[1]){
  case 'r' : 
    { // to get the state of ANALOGIC_IO
      Serial.print("/A r ");
      Serial.println(ANALOG_IO,DEC);
      break;
    }
  case 't' : 
    { // to get the period of analogic capture
      Serial.print("/A t ");
      Serial.println(ANALOG_PERIOD,DEC);
      break;
    }
  }
}

void setAnalogIO()
{
  switch(Cmd[1]){
  case 'r' : 
    { // to set the state of ANALOGIC_IO
      if(sizeCmd == 3){
        if(Cmd[2] > 0)
          ANALOG_IO = true;
        else
          ANALOG_IO = false;
      }
      break;
    }
  case 't' : 
    { // to set the period of analogic capture
      if(sizeCmd == 3){
        if(Cmd[2] > 0)
          ANALOG_PERIOD = Cmd[2];
      }
      break;
    }
  }
}


void getVersion()
{
  Serial.print("/V ");
  Serial.println(VERSION);
}
