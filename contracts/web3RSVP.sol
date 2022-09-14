// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4; 

contract web3RSVP {

    event NewEventCreated(
        bytes32 eventId, 
        address creatorAddress, 
        uint256 eventTimeStamp,
        uint256 maxCapacity, 
        uint256 deposit, 
        string eventDataCID
    ); 

    event NewRSVP(bytes32 eventID, address attendeeAddress); 

    event ConfirmedAttendee(bytes32 eventID, address attendeeAddress); 

    event DepositsPaidOut(bytes32 eventID); 

    struct CreateEvent {
        bytes32 eventId; 
        string eventDataCID; 
        address eventOwner; 
        uint256 eventTimeStamp; 
        uint256 deposit; 
        uint256 maxCapacity; 
        address[] confirmedRSVPs; 
        address[] claimedRSVPs; 
        bool paidOut; 
    }

    mapping(address => CreateEvent) public idToEvent; 
    
    // This function gets called when a user adds a new event in the frontend
    function createNewEvent(
        uint256 eventTimeStamp,  
        uint256 deposit, 
        uint256 maxCapacity, 
        string calldata eventDataCID
    ) external {
        // generate an event id based on the other things passed in to genrate a hash 
        bytes32 eventId = keccak256(
            abi.encodePacked(
                msg.sender, 
                address(this), 
                eventTimeStamp, 
                deposit, 
                maxCapacity
            )
        ); 

        address[] memory confirmedRSVPs; 
        address[] memory claimedRSVPs; 

        // This creates a new createEvent and adds it to the idToEvent mapping
        idToEvent[eventId] = CreateEvent(
            eventId, 
            eventDataCID,
            msg.sender, 
            eventTimeStamp, 
            deposit, 
            maxCapacity, 
            confirmedRSVPs, 
            claimedRSVPs, 
            false
        ); 

        emit NewEventCreated(
            eventId, 
            msg.sender,
            eventTimeStamp, 
            maxCapacity, 
            deposit, 
            eventDataCID
        ); 
    }

    // Function that gets called when a user RSVPs for an event
    function createNewRSVP(bytes32 eventId) external payable {

        // Look up our event from the mapping 
        CreateEvent storage myEvent = idToEvent[eventId]; 

        // Ensure they send enough eth to cover specific deposit requirement 
        require(msg.value == myEvent.deposit, "NOT ENOUGH");

        // Require that the event has already started 
        require(block.timestamp <= myEvent.timestamp, "ALREADY HAPPENED"); 

        // Make sure the event is not under max capacity 
        require(
            myEvent.confirmedRSVPs.length < myEvent.capacity, 
            "This event is already full"
        ); 

        // Ensure the msg sender isn't already in the myEvent.confirmedRSVPs || Hasn't already RSVP'd
        for (uint8 i = 0; i < myEvent.confirmedRSVPs.length; i++){
            require(myEvent.confirmedRSVPs[i] != msg.sender,"ALREADY CONFIRMED");
        }

        myEvent.confirmedRSVPs.push(payable(msg.sender)); 

        emit NewRSVP(eventId, msg.sender);

    }


    // This function confirm every person that RSVP'd to the event 
    function confirmAllAttendees(bytes32 eventId) external {
        // Look up event from the struct using the eventId 
        CreateEvent memory myEvent = idToEvent[eventId];

        // Require that the msg.sender is the owner of the event
        require(msg.sender = myEvent.eventOwner, "NOT AUTHORIZED"); 

        //  Confirm each attendee in the RSVP array
        for (uint i = 0; i < myEvent.confirmedRSVPs.length; i++){
            confirmAttendee(eventId, myEvent.confirmedRSVPs[i]); 
        }
    }

    function confirmAttendee(bytes32 eventId, address attendee) public { 
        // look up event from our struct using the eventId
        CreateEvent storage myEvent = idToEvent[eventId];  

        // Require that msg.sender is the owner of the event - only the host should be able to check people in
        require(msg.sender == myEvent.eventOwner, "NOT AUTHORIZED"); 

        // Require that attendee who tried to check in actually RSVP'd 
        address rsvpConfirm; 

        for (uint8 i = 0; i < myEvent.confirmedRSVPS.length; i++) {
            if(myEvent.confirmedRSVPs[i] == attendee){
                rsvpConfirm = myEvent.confirmedRSVPs[i]; 
            }
        }   

        require(rsvpConfirm == attendee, "NO RSVP TO CONFIRM"); 

        // Ensure that the attendee hasn't already checked in 
        for (uint8 i = 0; i < myEvent.claimedRSVPs.length; i++){
            require(myEvent.claimedRSVPs[i] != attendee, "ALREADY CLAIMED"); 
        }

        // Require that the deposits are not already claimed by the event owner
        require(myEvent.paidOut == false, "ALREADY PAID OUT"); 

        // Add attendee to the claimed RSVP list 
        myEvent.claimedRSVPs.push(attendee); 

        // Sending ether back to the staker 
        (bool sent,) = attendee.call{value: myEvent.deposit}(""); 

        // If sending the ether fails, remove the attendee from the list of claimed RSVPs 
        if(!sent){
            myEvent.claimedRSVPs.pop(); 
        }

        require(sent, "Failed to send ether"); 

        emit confirmAttendee(eventId, attendee);
    } 

    // Sending unclaimed deposits to event owner
    function withdrawUnclaimedDeposits(bytes32 eventId) external {
        // Look up the event 
        CreateEvent memory myEvent = idToEvent(eventId); 

        // Ensure that the money hasn't been paid out 
        require(!myEvent.paidOut, "ALREADY PAID"); 

        // Check if its been 7 days past event timestamp 
        require(
            block.timestamp >= (myEvent.eventTimeStamp + 7 days), 
            "TOO EARLY"
        ); 

        // Ensure that it is the event owner that is widthrawing 
        require(msg.sender == myEvent.eventOwner, "MUST BE EVENT OWNER");

        // Calculate how many people didn't recieve by comparison 
        uint256 unclaimed = myEvent.confirmedRSVPs.length - myEvent.claimedRSVPs.length; 

        // Calculate the amount to be paid out
        uint256 payout = unclaimed * myEvent.deposit; 

        // Mark as paid in order to avoid reentrancy attack 
        myEvent.paidOut = true;

        // Send the payout to the owner 
        (bool sent,) = msg.sender.call{value: payout}(""); 

        // If it fails 
        if(!sent){
            myEvent.paidOut = false;
        }   

        require(sent, "Failed to send Ether"); 

        emit DepositsPaidOut(eventId);
    }    
}