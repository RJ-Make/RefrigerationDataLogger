#include <SD.h> //#include <SdFat.h>  //#include <SD.h>
#include <IniFile.h>
#include <Wire.h>
#include "RTClib.h"
#include "DHT.h"
#include "EmonLib.h"
// how many milliseconds between grabbing data and logging it. 1000 ms is once a second
// NOTE **** Takes about 6.7 seconds to grab the temperature and humidity from all 3 sensors so this would be in adition to LOG_INTERVAL
int LogInterval = 7; // Seconds between entries (reduce to take more/faster data)
// how many Seconds before writing the logged data permanently to disk
// set it to the LOG_INTERVAL to write each time (safest)
// set it to 10*LOG_INTERVAL to write all data every 10 datareads, you could lose up to 
// the last 10 reads if power is lost but it uses less power and is much faster!
#define SYNC_INTERVAL 1000 // mills between calls to flush() - to write data to the card
uint32_t syncTime = 0; // time of last sync()

//Debug
#define ECHO_TO_SERIAL 0 // echo data to serial port
#define WAIT_TO_START  0 // Wait for serial input in setup()

// Pins
// the digital Pin that connect to the RED LED
#define redLEDpin	2
#define greenLEDpin 7

// This is the pin the Card Detect is attached
#define SDCardCkPin 8

//Start Stop Button Pin
#define StartStopButtonPin 9

//Anolog Light Pins
#define REF_LIGHT_PIN 0
#define FRE_LIGHT_PIN 3

//Temp Pins
#define REF_HUMIDITY_SENSOR_DIGITAL_PIN 3
#define FRE_HUMIDITY_SENSOR_DIGITAL_PIN 4
#define AMB_HUMIDITY_SENSOR_DIGITAL_PIN 5

// for the data logging shield, we use digital pin 10 for the SD cs line
const int chipSelect = 10;

// The analog pin that connect to the split CT (SCT013  100A:50mA)
#define iCURRENT_PIN 1 //A1

// Create an instances of Temp/Hum Sensors
DHT dhtREF;
DHT dhtFRE;
DHT dhtAMB;

// the logging file
File logfile;

//Log file name Is the Date Plus the Minute.
char LogfileName[13];

//Button Stuff
int currBtnState = HIGH;
int lastBtnState = HIGH;
bool LoggingState = false;
long time = 0; // the last time the output pin was toggled
int debounce = 100; // the debounce time, increase if the output flickers

// Create an instance of the Energy Monitor object
EnergyMonitor emon1;

// define the Real Time Clock object
RTC_DS1307 RTC; 
DateTime WriteDateTime;
String DateTimeStamp;

// the settings parameters
long WO_UnderTest = 123456;
int Equip_Voltage = 125;
bool IncludeREFSens = true;
bool IncludeFRESens = true;
bool IncludeAMBSens = true;

//Temp/Hum Vars
float REF_Humidity;
float REF_Temp;
float FRE_Humidity;
float FRE_Temp;
float AMB_Humidity;
float AMB_Temp;

// Current: PIN and calibration. 60
float iCurrent = 0;
const double iCurrentCalibration = 61.2; // Current: calibration. 60

// Light Vars
int REF_Light=0;
int FRE_Light=0;

void setup(void){

  Serial.begin(115200);
    // Setup the button
  pinMode(StartStopButtonPin, INPUT);
  digitalWrite(StartStopButtonPin,HIGH);
   
  // use debugging LEDs
  pinMode(redLEDpin, OUTPUT);
  pinMode(greenLEDpin, OUTPUT);
  
  // Used to check physical presence of SD Card
  pinMode(SDCardCkPin, INPUT_PULLUP);
  
  // Setup Light Pins
  pinMode(REF_LIGHT_PIN, INPUT);
  pinMode(FRE_LIGHT_PIN, INPUT);
   
  // setup the LED output now
  digitalWrite(redLEDpin,LOW);
  digitalWrite(greenLEDpin,LOW);
   
#if WAIT_TO_START
  Serial.println(F("Type any character to start"));
  while (!Serial.available());
#endif //WAIT_TO_START

  // Start RTC
   IniRTC();
   // initialize the SD card
   IniSDCard();  
  // Get the Setup Information
   loadSettings(); 
  //Start the logging file
   CreateLoggingFile();
  // checkin the sensors 
   IniDHT();
  // initialize the Current Sensor
   IniCurrent();
}

void loop(void){
currBtnState = digitalRead(StartStopButtonPin);
 if (currBtnState == LOW && lastBtnState == HIGH && millis() - time > debounce) {
	 if (LoggingState == false)
	   LoggingState = true;
	 else
	   LoggingState = false;
	 time = millis();
 }
 lastBtnState = currBtnState;
  StartLogging();
  } 

void StartLogging(){
   if (LoggingState == true) {
		digitalWrite(greenLEDpin,HIGH);
		// delay for the amount of time we want between readings
		delay(((LogInterval * 1000) -1) - (millis() % (LogInterval * 1000)));
		// Get Light Readings
		GetLight();
		//Get Current Reading
		GetCurrent();
		//Get Temps
		GetDHT();
		// Write the Information to the SD Card
		WriteToSDCard();
   } else {
		digitalWrite(greenLEDpin,LOW);
		if (logfile);
		{
			logfile.flush();
			if (digitalRead(StartStopButtonPin)==LOW) {
				delay(3000);
				
			}
		}	   
      }
}

void WriteToSDCard(){
//Make sure log is still available
	if (digitalRead(SDCardCkPin) == HIGH) {
		error(1);
	}
// see if the log is open:
	if (!logfile){
		error(8);
	}
////HEADER INFO ",WO,Time,Amps,Ref_Temp,Ref_Hum,Fre_Temp,Fre_Hum,Amb_Temp,Amb_Hum,Ref_Light,Fre_Light"

// fetch the time
WriteDateTime = RTC.now();
//Print empty line
logfile.print(',');
//Work Order Number
logfile.print(WO_UnderTest);
logfile.print(',');

// log time
logfile.print(WriteDateTime.month(), DEC);
logfile.print("/");
logfile.print(WriteDateTime.day(), DEC);
logfile.print("/");
logfile.print(WriteDateTime.year(), DEC);
logfile.print(" ");
logfile.print(WriteDateTime.hour(), DEC);
logfile.print(":");
logfile.print(WriteDateTime.minute(), DEC);
logfile.print(":");
logfile.print(WriteDateTime.second(), DEC);
logfile.print(',');
logfile.print(iCurrent);
logfile.print(',');
logfile.print(REF_Temp);
logfile.print(',');
logfile.print(REF_Humidity);
logfile.print(',');
logfile.print(FRE_Temp);
logfile.print(',');
logfile.print(FRE_Humidity);
logfile.print(',');
logfile.print(AMB_Temp);
logfile.print(',');
logfile.print(AMB_Humidity);
logfile.print(',');
logfile.print(REF_Light);
logfile.print(',');
logfile.print(FRE_Light);
logfile.println("");

#if ECHO_TO_SERIAL
//Print empty line
Serial.print(',');
//Work Order Number
Serial.print(WO_UnderTest);
Serial.print(',');
Serial.print(WriteDateTime.month(), DEC);
Serial.print("/");
Serial.print(WriteDateTime.day(), DEC);
Serial.print("/");
Serial.print(WriteDateTime.year(), DEC);
Serial.print(" ");
Serial.print(WriteDateTime.hour(), DEC);
Serial.print(":");
Serial.print(WriteDateTime.minute(), DEC);
Serial.print(":");
Serial.print(WriteDateTime.second(), DEC);
Serial.print(',');
Serial.print(iCurrent);
Serial.print(',');
Serial.print(REF_Temp);
Serial.print(',');
Serial.print(REF_Humidity);
Serial.print(',');
Serial.print(FRE_Temp);
Serial.print(',');
Serial.print(FRE_Humidity);
Serial.print(',');
Serial.print(AMB_Temp);
Serial.print(',');
Serial.print(AMB_Humidity);
Serial.print(',');
Serial.print(REF_Light);
Serial.print(',');
Serial.print(FRE_Light);
Serial.println("");
#endif //ECHO_TO_SERIAL

// Now we write data to disk! Don't sync too often - requires 2048 bytes of I/O to SD card
// which uses a bunch of power and takes time
if ((millis() - syncTime) < SYNC_INTERVAL) return;
syncTime = millis();
logfile.flush();	
}

//// GET THE CURRENT TEMP AND HUM READINGS ////
void GetDHT(){
	
	if (IncludeREFSens = 1)
	{ 
		delay(dhtREF.getMinimumSamplingPeriod());
		REF_Humidity = dhtREF.getHumidity();
		REF_Temp = dhtREF.getTemperature()*9/5 + 32;
	  
	    if (isnan(REF_Temp))
	    {
		  error(7);	
	    }
	}

	if (IncludeFRESens = 1)
	{
		delay(dhtFRE.getMinimumSamplingPeriod());
		FRE_Humidity = dhtFRE.getHumidity();
		FRE_Temp = dhtFRE.getTemperature()*9/5 + 32;
		
		if (isnan(FRE_Temp))
		{
			error(6);
		}
	}
	if (IncludeAMBSens = 1)
	{
		delay(dhtAMB.getMinimumSamplingPeriod());
		AMB_Humidity = dhtAMB.getHumidity();
		AMB_Temp = dhtAMB.getTemperature()*9/5 + 32;
		
		if (isnan(AMB_Temp))
		{
			error(5);
		}
	}
}

//// GET THE LIGHT VALUE READINGS ////
void GetLight(){
   REF_Light = analogRead(REF_LIGHT_PIN); 
   FRE_Light = analogRead(FRE_LIGHT_PIN); 
   
   	#if ECHO_TO_SERIAL
   	  Serial.print(F("REF Light Level: "));
   	  Serial.println(REF_Light);
   	delay(50);
   	  Serial.print(F("FRE Light Level: "));
   	  Serial.println(FRE_Light);
   	delay(50);
   	#endif //ECHO_TO_SERIAL
	   
}

void GetCurrent(){
	iCurrent = emon1.calcIrms(1480);
	if (iCurrent <= 0.20){
		iCurrent = 0;
	}
	#if ECHO_TO_SERIAL	
		Serial.print(iCurrent*230.0);	       // Apparent power
		Serial.print(F(" "));
		Serial.println(iCurrent);		       // Irms
	#endif //ECHO_TO_SERIAL	

}

//////////////////////////// INITIALIZATION SECTION BELOW ////////////////////////////
//
//
//
//
/////////////////////////////////////////////////////////////////////////////////////

//// SD CARD AND READER ////
void IniSDCard(){
 	// initialize the SD card
	Serial.print(F("Initializing SD card..."));
	delay(50);
   // Start SD Card Reader
   // make sure that the default (10) chip select pin is set to
   // output, even if you don't use it:
   pinMode(10, OUTPUT);
     if (!SD.begin(chipSelect)) {
	   error(4);
   }	
	Serial.println(F("card initialized."));
	delay(50);
}

void CreateLoggingFile(){
	 //Create the Name for the Logging File
     CreateLoggingFileName(LogfileName);

	if (!SD.exists(LogfileName)) {
		// only open a new file if it doesn't exist
		logfile = SD.open(LogfileName, FILE_WRITE);
	}
	if (! logfile) {
		error(3);
	}
	   logfile.println(F(",WO,Time,Amps,Ref_Temp,Ref_Hum,Fre_Temp,Fre_Hum,Amb_Temp,Amb_Hum,Ref_Light,Fre_Light"));
	   delay(125);
	#if ECHO_TO_SERIAL
	Serial.print(F("Logging to: "));
	Serial.println(LogfileName);
	delay(50);
	Serial.print(F("With a Header of: "));
	Serial.println(F(",WO,Time,Amps,Ref_Temp,Ref_Hum,Fre_Temp,Fre_Hum,Amb_Temp,Amb_Hum,Ref_Light,Fre_Light"));
	delay(50);
	#endif //ECHO_TO_SERIAL
}

void CreateLoggingFileName(char *filename){
 DateTime now = RTC.now(); 
 int year = now.year(); int month = now.month(); int day = now.day(); int hour = now.hour(); int minutes = now.second(); int seconds = now.second();
 
    filename[0] = month/10 + '0';
    filename[1] = month%10 + '0';   
    filename[2] = day/10 + '0';
    filename[3] = day%10 + '0';	
	filename[4] = '1';  //year/10 + '0';
    filename[5] = year%10 + '0';
	filename[6] = 0;
	filename[7] = 0;
	filename[8] = '.';
	filename[9] = 'C';
	filename[10] = 'S';
	filename[11] = 'V';
   // We will fill in the last 2 spaces with a random number from 00 to 99	
   for (uint8_t i = 0; i < 100; i++) 
     {
	   filename[6] = i/10 + '0';
	   filename[7] = i%10 + '0';
		 if (! SD.exists(filename)) {
			 break; // leave the loop!
		 }	   
     }	
    return;
}

//// REAL TIME CLOCK ////
void IniRTC(){
 Wire.begin();
 RTC.begin();
}

//// DHT SENSORS ////
void IniDHT(){
	dhtREF.setup(REF_HUMIDITY_SENSOR_DIGITAL_PIN);
	dhtFRE.setup(FRE_HUMIDITY_SENSOR_DIGITAL_PIN);
	dhtAMB.setup(AMB_HUMIDITY_SENSOR_DIGITAL_PIN);
}

void IniCurrent(){
	//emon1.voltage(2, 234.26, 1.7);  // Voltage: input pin, calibration, phase_shift
	emon1.current(iCURRENT_PIN, iCurrentCalibration);       // Current: input pin, calibration. 60
}

//// ERROR FUNCTION ////
void error(int errortype)
{
	switch(errortype) {
		
	case 1:
	 Serial.println(F("error: Failed to Open Settings File"));
	 while(1){
		    digitalWrite(greenLEDpin,LOW);
			digitalWrite(redLEDpin, HIGH);
			delay(500);
			digitalWrite(redLEDpin, LOW);
			delay(2000);
	 }
	case 2:
	 Serial.println(F("error: Settings File Not Valid"));
		 while(1){
			 digitalWrite(greenLEDpin,LOW);
			 digitalWrite(redLEDpin, HIGH);
			 delay(500);
			 digitalWrite(redLEDpin, LOW);
			  delay(500);
		 }
	case 3:
	Serial.println(F("error: Could Not Create a Valid Log File"));
		 while(1){
			 digitalWrite(greenLEDpin,LOW);
			 digitalWrite(redLEDpin, HIGH);
			 delay(500);
			 digitalWrite(redLEDpin, LOW);
			 delay(1000);
		 }
	break;
	case 4:
	Serial.println(F("error: Could Not Connect to SD Reader"));
		 while(1){
			 digitalWrite(greenLEDpin,LOW);
			 digitalWrite(redLEDpin, HIGH);
			 delay(100);
			 digitalWrite(redLEDpin, LOW);
			 delay(100);
		 }
	case 5:
	Serial.println(F("error: Could Not Read AMB. Temp Sensor"));
			 while(1){
				 digitalWrite(greenLEDpin,LOW);
				 digitalWrite(redLEDpin, HIGH);
				 delay(5000);
				 digitalWrite(redLEDpin, LOW);
				 delay(3000);
			 }
	case 6:
	Serial.println(F("error: Could Not Read FRE. Temp Sensor"));
			 while(1){
				 digitalWrite(greenLEDpin,LOW);
				 digitalWrite(redLEDpin, HIGH);
				 delay(5000);
				 digitalWrite(redLEDpin, LOW);
				 delay(2000);
			 }
	break;
	case 7:
	Serial.println(F("error: Could Not Read REF. Temp Sensor"));
			 while(1){
				 digitalWrite(greenLEDpin,LOW);
				 digitalWrite(redLEDpin, HIGH);
				 delay(5000);
				 digitalWrite(redLEDpin, LOW);
				 delay(1000);
			 }
	break;
	case 8:
	Serial.println(F("error: Log File Not Open"));
	break;
	}
	//// red LED indicates error
	//digitalWrite(redLEDpin, HIGH);
	//digitalWrite(greenLEDpin,LOW);
	//while(1);
}

//////////////////////////// SETTINGS SECTION BELOW ////////////////////////////

//// PULL SETTINGS FROM SD CARD NOT COMPLETED ////
void loadSettings()
{
 const size_t bufferLen = 80;
 char buffer[bufferLen];
 const char *filename = "/settings.ini";

IniFile ini(filename);
  Serial.println(freeRam ());
  
 if (!ini.open()) {
	 error(1);
 }
 Serial.println(F("Ini file exists"));

 // Check the file is valid. This can be used to warn if any lines
 // are longer than the buffer.
 if (!ini.validate(buffer, bufferLen)) {
	 Serial.println(F("Ini File Not Valid"));
	 error(2);
 }
 
 // Fetch a value from a key which is present
 ini.getValue("Job Site Info", "WO", buffer, bufferLen,WO_UnderTest);
 ini.getValue("Sensors","Voltage", buffer, bufferLen,Equip_Voltage);
 ini.getValue("Sensors","RefSensor", buffer, bufferLen,IncludeREFSens);
 ini.getValue("Sensors","FreSensor", buffer, bufferLen,IncludeFRESens);
 ini.getValue("Sensors","AmbSensor", buffer, bufferLen,IncludeAMBSens);
 ini.getValue("Sensors","LogIntervalSeconds", buffer, bufferLen,LogInterval);
 
 
  ini.close();	
}

int freeRam ()
{
	extern int __heap_start, *__brkval;
	int v;
	return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}