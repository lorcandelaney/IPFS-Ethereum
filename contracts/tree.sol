/*My concerns:
1.) How do you insure that someone gives you the correct id? if you dont want to use ids as a means to find the file hash on the blockchain then how else will you find
them?

2.)No real way of insuring that people dont abuse the system to get coins etc.


**/
pragma solidity ^0.4.13;

//1 instance of the smart contract per corporation/group that uses it. So the smart contract keeps track of all file distributors for that corporation/group.

import './TrialCoin.sol';
import "./strings.sol"; //gives you the ability to do string manipulations
contract Tree {

    using strings for *;
    
    struct Distributor {
        address referrer; //person who introduced you to the network
        address distributor_add; //your address
        bool isBanned;
        bool isInit; //are you initialised
        string disId; //your id, calculated from your height in the tree and your branch no starting from the left going right
        bytes32 childrenNo; //how many children you have
    }

    
    struct File {
        string link; // ipfs hash
        address committer; //file creator address
        Distributor[] distributors; //all the dstrubutors of this file
        bool exists; 
        uint256 balance; //This is the credit that's left for this file. A file can only be distributed as long as credit remains for it. Each time it gets distributed, the credit decreases. This credit can be topped up.
    }
    
    // hash-map where bytes32 = id of file
    mapping(bytes32 => File) files;

    //distrib map to check for bans
    mapping(address => Distributor) distributorMap;
    mapping(bytes32 => bool) outOfFunds;
    mapping(bytes32 => mapping(address => bool)) payed; //wether a distributor has been payed yet for a given file.
    address public owner;

    //the amount of funds attached to a contract that triggers a lowfund event
    uint256 threshold;
    //the rate of our token/eth
    uint256 coinRate;

    TrialCoin token;
    
    modifier isUnique(bytes32 id) {
        require(!files[id].exists);
        _;
    }
    
    modifier onlyOwner{
        require(owner == msg.sender);
        _;
    }
    
    event lowFunds(bytes32 id);

    event noFunds(bytes32 id);

    event checkForPayment(string disId);
    
    function Tree(uint256 rate, uint256 lowFundCap){

        owner = msg.sender;
        coinRate = rate;
        threshold = lowFundCap;
        token = createTokenContract();
        
    }
    
    function addFile(bytes32 id, string link, address original_distributor) 
    payable 
    onlyOwner
    isUnique(id) 
    {
        // msg.sender is the committer
        // e.g. BBC

        //setup file info
        File storage file;
        file.link = link;
        file.committer = msg.sender;
        file.exists = true;
        file.balance = msg.value*coinRate;

        //setup distributor info
        Distributor storage distributor;
        distributor.referrer = msg.sender;
        distributor.distributor_add = original_distributor;
        distributor.isBanned = false;
        distributor.isInit = true;
        distributor.disId = "0";
        distributor.childrenNo = bytes32(0);

        distributorMap[original_distributor] = distributor;
        //this might be problematic if you want original_distributor to be dynamic

        //store the data
        file.distributors.push(distributor);
        files[id] = file;
        
    }

    //The organisation/group that owns the file and hence this contract can increase the balance/credit for a file so it can be distributed more.
    function topUp(bytes32 id) external payable onlyOwner{
        //not sure what to do with the ether that amasses on the contract
        uint256 topUpAmt = msg.value*coinRate;

        files[id].balance = files[id].balance + topUpAmt;        
    }

    //This is called by a person who is already a distributor. It allows a current distributor to add a new one.
    //Also implements functionality allowing us to find the id of the inviter given an invitee.
    function addDistributor(bytes32 id, address invitee) external returns(bool){

        require(distributorMap[invitee].isBanned != false);

        require(distributorMap[invitee].isInit != true);

        //if the file has associated funds hen set up a new distributor profile
        if(outOfFunds[id] != true){

            Distributor storage distributor;
            distributor.referrer = msg.sender;
            distributor.distributor_add = invitee;
            distributor.isBanned = false;
            distributor.isInit = true;

            distributorMap[msg.sender].childrenNo = bytes32(uint(distributorMap[msg.sender].childrenNo) + 1);

            distributor.childrenNo = bytes32(0);

            string memory childrenNoString = bytes32ToString(distributorMap[msg.sender].childrenNo); //create a string that contains callers childrenNo

            distributor.disId = distributorMap[msg.sender].disId.toSlice().concat(childrenNoString.toSlice()); //the new distributors id is the old distributors id with their childrenNo on the end.

            distributorMap[invitee] = distributor;

            files[id].distributors.push(distributor);

            //files[id].balance = files[id].balance -1;

            //could update this to draw from a finite pool set by contract creator
            //token.mint(inviter, 1);

            checkForPayment(distributor.disId);

            return true;
        }

        else{
            noFunds(id);
            return false;
        }

    }


    function makePayment(bytes32 fileId, string disId) external returns(bool){
        //needs update for multiple files
        require(payed[fileId][msg.sender] != true);

        //match the disId of the claimant with the disId of the person a child/they signed up
        //if there is a match then the claimant must have the new distributor as a child and they can be paid

        //slice memory compare = disId.toSlice().find(distributorMap[msg.sender].disId.toSlice()); 

        bool check = strings.equals(disId.toSlice().find(distributorMap[msg.sender].disId.toSlice()),disId.toSlice());
        if(check){ 

            if(files[fileId].balance >=1){

                files[fileId].balance = files[fileId].balance -1;

                token.mint(msg.sender, 1);

                payed[fileId][msg.sender] = true; //they have now been paid so no more payments

            }

            else{
                outOfFunds[fileId] = true;
            }
        }
    }
    
    // Called by the end user
    function getFile(bytes32 id) external returns(string){
        //TODO: Who is the distributor? 
        //TODO: Does the file have enough funds to pay the chain of distribution? 
        //TODO: If so: Just do it! Move the funds, pay the distributors and deliver the file...
       
        //not sold on this, doing a for loop over distributors is pretty infeasible in the long term
        /*
        pay childDistributor;
        for(childDistributor.parents...) {
            pay parents;
        }

        **/
        if(files[id].balance < threshold){
            lowFunds(id);
        }

        return  files[id].link; //return ipfs hash

    }

    function createTokenContract() internal returns(TrialCoin){

        return new TrialCoin();

    }
    
    function banDistributor(address distrib) external onlyOwner{

        distributorMap[distrib].isBanned = true;
        
    }

    function getDisId(address distrib) external returns(string){
        return distributorMap[distrib].disId;
    }

    function bytes32ToString (bytes32 data) internal returns (string) { //creates string from int
        bytes memory bytesString = new bytes(32);
        for (uint j=0; j<32; j++) {
            byte char = byte(bytes32(uint(data) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[j] = char;
        }
            }

        return string(bytesString);
    }

}