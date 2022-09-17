const hre = require("hardhat"); 

const main = async () => {
    // Deploy the contract locally using hardhat
    const rsvpContractFactory = await hre.ethers.getContractFactory("Web3RSVP"); 
    const rsvpContract = await rsvpContractFactory.deploy(); 
    await rsvpContract.deployed(); 
    console.log("Contract deployed to: ", rsvpContract.address); 

    // Simulate different wallets interacting with the contract
    const [deployer, address1, address2] = await hre.ethers.getSigners(); 

    // Define the event data before we create a new event
    let deposit = hre.ethers.utils.parseEther("1");
    let maxCapacity = 5;
    let timestamp = 1718926200;
    let eventDataCID = "bafybeibhwfzx6oo5rymsxmkdxpmkfwyvbjrrwcl7cekmbzlupmp5ypkyfi";

    // Create a new event using the mock data 
    let txt = await rsvpContract.createNewEvent(
        deposit, 
        maxCapacity, 
        timestamp, 
        eventDataCID
    ); 

    let wait = await txt.wait(); 
    console.log("NEW EVENT CREATED:", wait.events[0].event, wait.events[0].args); 

    let eventID = wait.events[0].args.eventID; 
    console.log("EVENT ID: ", eventID); 

    txn = await rsvpContract.createNewRSVP(eventID, {value: deposit}); 
    wait = await txn.wait(); 
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args); 

    // RSVP to the event using other wallet addresses
    txn = await rsvpContract
          .connect(address1) 
          .createNewRSVP(eventID, {value: deposit}); 
    wait = await txn.wait(); 
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args); 

    txn = await rsvpContract
          .connect(address2)
          .createNewRSVP(eventID, {value: deposit})
    wait = await txn.await(); 
    console.log("NEW RSVP:", wait.events[0].event, wait.events[0].args); 

    // Confirm all the attendees
    txn = await rsvpContract.confirmAllAttendees(eventID); 
    wait = await txn.wait(); 
    wait.events.forEach((event) => {
        console.log("CONFIRMED:", event.args.attendeeAddress)
    }); 

    // Increase time to 10 years in order to be able to withdraw the deposits
    await hre.network.provider.send("evm_increaseTime", [15778800000000])

    txn = await rsvpContract.withdrawUnclaimedDeposits(eventID)
    wait = await txn.wait()
    console.log("WITHDRAW:", wait.events[0].event, wait.events[0].args)

}; 

const runMain = async () => {
    try {
        await main()
        process.exit(0) 
    } catch (error) {
        console.log(error) 
        process.exit(1)
    }
}; 

runMain(); 