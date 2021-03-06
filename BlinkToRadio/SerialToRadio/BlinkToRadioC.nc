#include <Timer.h>
#include "BlinkToRadio.h"

module BlinkToRadioC {
	uses interface Boot;
	uses interface Leds;
	
	uses interface Packet as SerialPacket;
	uses interface AMPacket as RadioAMPacket;
	
	uses interface AMSend as RadioAMSend;
	uses interface SplitControl as SerialAMControl;
	uses interface SplitControl as RadioAMControl;
	uses interface Receive as SerialReceive;
}

implementation {
	uint16_t counter = 1;
	bool busy = FALSE;
	message_t pkt;
	
	event void Boot.booted() {
		call SerialAMControl.start();
	}
	
	event void SerialAMControl.startDone(error_t err)
	{
		if (err == SUCCESS) {
			call RadioAMControl.start();
		}
		else {
			call SerialAMControl.start();
		}
	}
	
	event void RadioAMControl.startDone(error_t err)
	{
		if (err != SUCCESS) {
			call RadioAMControl.start();
		}
	}
	
	event void RadioAMSend.sendDone(message_t* msg, error_t err)
	{
		if(&pkt == msg) {
			busy = FALSE;
		}
	}
	
	event void RadioAMControl.stopDone(error_t err) { }
	
	event void SerialAMControl.stopDone(error_t err) { }
	
	event message_t* SerialReceive.receive(message_t* msg, void* payload, uint8_t len) {
		if(len == sizeof(BlinkToRadioMsg) && !busy) {
			BlinkToRadioMsg *btrpkt_rx = (BlinkToRadioMsg*)payload;
			BlinkToRadioMsg *btrpkt_tx = (BlinkToRadioMsg*)(call SerialPacket.getPayload(&pkt, (int)NULL));
			
			btrpkt_tx->counter = btrpkt_rx->counter;
			
			call Leds.set(btrpkt_rx->counter);
			if(call RadioAMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
				busy = TRUE;
			}
		}
		return msg;		
	}
}

