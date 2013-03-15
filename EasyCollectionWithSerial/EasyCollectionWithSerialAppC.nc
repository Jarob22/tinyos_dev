#include "EasyCollectionWithSerial.h"

configuration EasyCollectionWithSerialAppC{}

implementation {

	components EasyCollectionWithSerialC, MainC, LedsC, ActiveMessageC;
	
  components SerialActiveMessageC as AM;
  EasyCollectionWithSerialC.SerialControl -> AM;
	
  EasyCollectionWithSerialC.AMSend -> AM.AMSend[AM_TEST_SERIAL_MSG];
  EasyCollectionWithSerialC.Packet -> AM;


	components CollectionC as Collector;
	components new CollectionSenderC(0xee);
	
	EasyCollectionWithSerialC.Boot -> MainC;
	EasyCollectionWithSerialC.RadioControl -> ActiveMessageC;
	
	EasyCollectionWithSerialC.RoutingControl -> Collector;
	EasyCollectionWithSerialC.Leds -> LedsC;
	
	EasyCollectionWithSerialC.Send -> CollectionSenderC;
	
	EasyCollectionWithSerialC.RootControl -> Collector;
	EasyCollectionWithSerialC.Receive -> Collector.Receive[0xee];
	
	components new TimerMilliC();	
	EasyCollectionWithSerialC.Timer -> TimerMilliC;

	
}
