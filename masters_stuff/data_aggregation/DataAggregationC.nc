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
  uint16_t pauseCounter = 0
  uint16_t samples[160];
  bool classification[160];
  uint16_t roc[160][2];
  uint16_t nroc = 0;
  uint16_t f[160];
  const uint16_t maxReadings = 160;
  uint16_t THR = 0;
  uint16_t calibrationState = 0; // 0 = calib, 1 = calc, 2 = ready
  uint16_t TARGET;
  
  void swap (uint16_t i, uint16_t j) {
  	uint16_t tmp = samples[i];
  	bool b = classification[i];
  	samples[i] = samples[j];
  	samples[j] = tmp;
  	classification[i] = classification[j];
  	classification[j] = b;
	}
	
	void sort (uint16_t left, uint16_t right) {
		uint16_t i;
		bool swapped = true;
		while(swapped) {
			swapped = false;
			for(i = (left+1); i <= right; i++)
			{
				if(samples[i-1] < samples[i]) {
					swap( (i-1), i);
					swapped = true;
				}
			}
		}
	}
	
	task void calculateROC() {
		uint16_t i, fp = 0, tp = 0, fprev = 0;
		sort(0, 160 - 1);
		nroc = 0;
		for(i = 0; i < 160; i++) {
			if(classification[i] == true)
				tp++;
			else
				fp++;
			if(samples[i] != fprev) {
				fprev = samples[i];
				f[nroc] = fprev;
				roc[nroc][0] = fp;
				roc[nroc][1] = tp;
				if(fp/tp >= 0.1)
					THR = fprev;
				nroc++;
			}
		}
	}
  	
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
		if(err != SUCCESS) {
			call RadioControl.start();

		}
		else{
				call RoutingControl.start();
			if(TOS_NODE_ID == 1) {
				call RootControl.setRoot();

			}
			else {
				call Timer.startPeriodic(500);

			}
		}
	}

	
	event void RadioControl.stopDone(error_t err){}
	
	void sendMessage(uint16_t val){
	 	
			DataAggregationMsg* msg = (DataAggregationMsg*)call Send.getPayload(&packet,sizeof(DataAggregationMsg));
			msg->nodeid = TOS_NODE_ID;
			msg->data = val;
			if(call Send.send(&packet,sizeof(DataAggregationMsg)) == SUCCESS)
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
		//call Leds.led2Toggle();
		
		call Read.read();
	//		sendMessage();
	}
	
	event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	  //call Leds.led1Toggle();
    if (&packet == bufPtr) {
    	//call Leds.led1Toggle();
      locked = FALSE;
    }
  }
		
	event void Send.sendDone(message_t* m, error_t err){
	  call Leds.led1Toggle();
		//if(err != SUCCESS)
		sendBusy=FALSE;
	}
	
	
	void doMathsStuff(uint16_t data, uint16_t nodeID)
	{
		//call Leds.led1Off();
		numReadings++;
		if(data > MAXdata)
		{
			MAXdata = data;
			maxID = nodeID;
			
		}
		call Leds.set(maxID);
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

		if (locked) {
			return msg;
		}
		else {
			DataAggregationMsg* rcm = (DataAggregationMsg*)payload;
			DataAggregationMsg* sendMsg = (DataAggregationMsg*)(call Packet.getPayload(&packet, sizeof(DataAggregationMsg)));		
			
			if(len == sizeof(DataAggregationMsg) && rcm != NULL) {
				
				doMathsStuff(rcm->data, rcm->nodeid);
				if(calibrationState == 0)
				{
					if(counter < maxReadings/2) //first 40 readings
					{
						samples[counter] = rcm->data;
						classification[counter] = true;
						counter++;
					}
					else if(pauseCounter == 6) //second 40 readings
					{
						Leds.set(0);
						if(counter >= maxReadings/2 && counter < maxReadings)
						{
							samples[counter = rcm->data;
							classification[counter] = false;
							counter++;
						}
					}
					else if(counter == maxReadings/2) //set red led on for 3 seconds (6 readings)
					{
						if(pauseCounter < 6)
						{
							pauseCounter++;
							Leds.set(2);
						}
					}
					else if(counter == maxReadings) //set green led on for 3 seconds (6 readings)
					{
						if(pauseCounter < 12)
						{
							Leds.set(1);
							pauseCounter++;
						}
					}			
					else if(pauseCounter == 12) //turn leds off
					{
						Leds.set(0);	
						calibrationState = 1;
					}					
				}
				else if(calibrationState == 1)
				{
					calculateROC();
					calibrationState = 2;
					pauseCounter = 0;
				}
				else if(calibrationState == 2)
				{
					
					if(MAXdata > THR)
					{
						if(pauseCounter < 2)
						{
							Leds.set(2)
							pauseCounter++;
						}
						if(pauseCounter < 4 && pauseCounter >=2)
						{
							Leds.set(maxID)
							TARGET = 1;
						}
					}
					else
					{
						TARGET = 0
						if(pauseCounter < 4)
						{
							Leds.set(1);
							pauseCounter++;
						}
					}
				}
				(*sendMsg) = (*rcm);

				if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(DataAggregationMsg)) == SUCCESS) {
					locked = TRUE;
				}
			}
			
		}
		return msg;
	}
}
