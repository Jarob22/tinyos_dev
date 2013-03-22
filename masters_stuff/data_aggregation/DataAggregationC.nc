#include <Timer.h>
#include "DataAggregation.h"

module DataAggregationC{
uses interface Boot;
uses interface SplitControl as RadioControl;
uses interface SplitControl as SerialControl;
uses interface StdControl as RoutingControl;
uses interface Send;
uses interface Leds;
uses interface Timer<TMilli>;
uses interface RootControl;
uses interface Receive;
uses interface AMSend;
uses interface Packet;
uses interface Read<uint16_t>;
}
 
implementation {
	message_t packet;
	bool sendBusy = FALSE;
  bool locked = FALSE;
  uint16_t counter = 0;
  uint16_t lastVal = 0;
  uint16_t MAXdata = 0;
  uint16_t MINdata = 0;
  uint16_t AVGdata = 0;
  uint16_t maxID = 0;
  uint16_t minID = 0;
  uint16_t numReadings = 0;
  uint16_t totalForAverage = 0;
  
	
	typedef nx_struct DataAggregationMsg{
	nx_uint16_t data;
	nx_uint16_t nodeid;
	} DataAggregationMsg;



	event void Boot.booted(){
		call SerialControl.start();
	}
	
	event void SerialControl.startDone(error_t err) {
		if(err != SUCCESS)
			call SerialControl.start();
		else {
			call RadioControl.start();
		}
	}
	
	event void SerialControl.stopDone(error_t err) {}
		
	event void RadioControl.startDone(error_t err){
		if(err != SUCCESS)
			call RadioControl.start();
		else{
				call RoutingControl.start();
			if(TOS_NODE_ID == 1) {
				call RootControl.setRoot();
				//call Leds.led1On();
			}
			else {
				call Timer.startPeriodic(500);
				//call Leds.led0On();
			}
		}
	}

	
	event void RadioControl.stopDone(error_t err){}
	
	void sendMessage(uint16_t val){
	 	
			DataAggregationMsg* msg = (DataAggregationMsg*)call Send.getPayload(&packet,sizeof(DataAggregationMsg));
			msg->nodeid = TOS_NODE_ID;
			msg->data = val;
			if(call Send.send(&packet,sizeof(DataAggregationMsg)) != SUCCESS)
				{}
			else
				sendBusy=TRUE;
	}
	
	event void Read.readDone(error_t err, uint16_t val)
	{
		if(err == SUCCESS)
		{
			if(!sendBusy)
				sendMessage(val);
		}
	}
		
	event void Timer.fired(){
		call Leds.led2Toggle();
		
		call Read.read();
	//		sendMessage();
	}
	
	event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	  call Leds.led2Off();
    if (&packet == bufPtr) {
    	call Leds.led1Toggle();
      locked = FALSE;
    }
  }
		
	event void Send.sendDone(message_t* m, error_t err){
		if(err != SUCCESS)
			call Leds.led0Toggle();
		sendBusy=FALSE;
	}
	
	
	void doMathsStuff(uint16_t data, uint16_t nodeID)
	{
		numReadings++;
		if(data > MAXdata)
		{
			MAXdata = data;
			maxID = nodeID;
		}
		if(data < MINdata)
		{
			MINdata = data;
			minID = nodeID;
		}
		totalForAverage += data;
		AVGdata = totalForAverage/numReadings;
	}
	
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		//call Leds.led2Toggle();
		if (locked) {
			return msg;
		}
		else {
			DataAggregationMsg* rcm = (DataAggregationMsg*)payload;
			DataAggregationMsg* sendMsg = (DataAggregationMsg*)(call Packet.getPayload(&packet, sizeof(DataAggregationMsg)));		
			
			if(len == sizeof(DataAggregationMsg) && rcm != NULL) {
				call Leds.led0Toggle();
				doMathsStuff(rcm->data, rcm->nodeid);
				(*sendMsg) = (*rcm);
				
				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(DataAggregationMsg)) == SUCCESS) {
				
					call Leds.led2On();
					locked = TRUE;
				}
			}
			
			//if (call Packet.maxPayloadLength() < sizeof(DataAggregationMsg)) {
				//return msg;
			//}
			
		}
		return msg;
	}
}
