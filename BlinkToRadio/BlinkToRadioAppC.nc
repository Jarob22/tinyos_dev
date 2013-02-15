#include <Timer.h>
#include "BlinkToRadio.h"

configuration BlinkToRadioAppC {
}

implementation {
	components MainC;
	components LedsC;
	components BlinkToRadioC as App;
	components new TimerMilliC() as Timer0;
	components ActiveMessageC;
	//components new AMSenderC (AM_BLINKTORADIOMSG);
	//components new AMReceiverC (AM_BLINKTORADIOMSG);
	components SerialActiveMessageC;
	components new SerialAMSenderC (AM_BLINKTORADIOMSG);
	
	
	App.Boot -> MainC;
	App.Leds -> LedsC;
	App.Timer0 -> Timer0;
	App.Packet -> SerialAMSenderC;
	App.AMPacket -> SerialAMSenderC;
	App.AMSend -> SerialAMSenderC;
	App.AMControl -> SerialActiveMessageC;
	//App.Receive -> AMReceiverC;
}
