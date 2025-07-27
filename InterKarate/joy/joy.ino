const int axisX1=A0; // ось Х подключена к A0
const int axisY1=A1; // ось Y подключена к A1
const int axisZ1=2; // ось Z (кнопка джойстика) подключена к D2
const int axisX2=A2; // ось Х подключена к A2
const int axisY2=A3; // ось Y подключена к A3
const int axisZ2=3; // ось Z (кнопка джойстика) подключена к D2
int valX, valY, valZ = 0; // переменные для хранения значений осей

void setup()
{
  pinMode(axisZ1, INPUT_PULLUP); // конфигурируем D2 как INPUT с включением
  pinMode(axisZ2, INPUT_PULLUP); // конфигурируем D2 как INPUT с включением
  // подтягивающего резистора внутри процессора
  Serial.begin(9600);
}

void loop() {
  valX = analogRead(axisX1); // значение оси Х
  valY = analogRead(axisY1); // значение оси Y
  valZ = 1-digitalRead(axisZ1); //
  // Serial.print(valX);
  // Serial.print(" - ");
  // Serial.println(valY);
  long valResult=100100;

  if (valY<470)
    valResult=valResult+10;
  else if (valY>530)
    valResult=valResult+20;
  if (valX<470)
    valResult=valResult+1;
  else if (valX>530)
    valResult=valResult+2;
  if (valZ>0)
    valResult=valResult+100;
  
  valX = analogRead(axisX2); // значение оси Х
  valY = analogRead(axisY2); // значение оси Y
  valZ = 1-digitalRead(axisZ2); //
  
  // Serial.print(valX);
  // Serial.print(" - ");
  // Serial.println(valY);

  if (valY<470)
    valResult=valResult+10000;
  else if (valY>530)
    valResult=valResult+20000;
  if (valX<470)
    valResult=valResult+1000;
  else if (valX>530)
    valResult=valResult+2000;
  if (valZ>0)
    valResult=valResult+100000;
  if (valResult>100100)
  {
    Serial.print(valResult);
    Serial.println("");    
  }
  delay(50); // пауза перед следующим считыванием данных
}