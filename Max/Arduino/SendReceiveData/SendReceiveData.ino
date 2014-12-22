void setup()
{
  Serial.begin(9600);
  Serial.setTimeout(50);
}

void loop() 
{
  int myInt;
  
  while (Serial.available() > 0)
  {
    myInt = Serial.parseInt();
    Serial.println(myInt);
  }
  
  delay(20);
}

String parseString()
{
  String s;
  boolean done = false;

  // tant que des données arrivent sur le port série
  while (!done)
  {
    if (Serial.available() > 0)
    {
      // lecture d'une lettre
      char c = Serial.read();

      // si la lettre n'est pas le signe du retour à la ligne
      if (c != '\n')
      {
        // on ajoute la lettre à la phrase
        s += c;
      }
      // sinon c'est terminé
      else done = true;
    }
  }

  return s;
}


