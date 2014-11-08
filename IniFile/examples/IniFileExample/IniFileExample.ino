#include <SD.h>
#include <IniFile.h>

// The select pin used for the SD card
#define SD_SELECT 10

  long WO_UnderTest;
  long Equip_Voltage;

void setup()
{
  // Configure all of the SPI select pins as outputs and make SPI
  // devices inactive, otherwise the earlier init routines may fail
  // for devices which have not yet been configured.
  pinMode(SD_SELECT, OUTPUT);
  
  const size_t bufferLen = 80;
  char buffer[bufferLen];

  const char *filename = "/settings.ini";
  Serial.begin(115200);
  //SPI.begin();
  if (!SD.begin(SD_SELECT))
    while (1)
      Serial.println("SD.begin() failed");
  
 IniFile ini(filename);
 Serial.println(freeRam ());
 
 
 if (!ini.open()) {
	 Serial.print("Ini file ");
	 Serial.print(filename);
	 Serial.println(" does not exist");
	 //error("Ini Setting File Does NOt Exist");
 }
 Serial.println("Ini file exists");

 // Check the file is valid. This can be used to warn if any lines
 // are longer than the buffer.
 if (!ini.validate(buffer, bufferLen)) {
	 Serial.print("ini file ");
	 Serial.print(ini.getFilename());
	 Serial.print(" not valid: ");
	//error("Setting File Is Not Valid");
 }
 
  // Fetch a value from a key which is present
  ini.getValue("Job Site Info", "WO", buffer, bufferLen,WO_UnderTest);
  Serial.println(WO_UnderTest);
  
  ini.getValue("Sensors", "Voltage", buffer, bufferLen,Equip_Voltage);
  Serial.println(Equip_Voltage);
  ini.close();
}


void loop()
{


}

int freeRam ()
{
	extern int __heap_start, *__brkval;
	int v;
	return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}