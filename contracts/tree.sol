/*My concerns:
1.) How do you insure that someone gives you the correct id? if you dont want to use ids as a means to find the file hash on the blockchain then how else will you find
them?

2.)No real way of insuring that people dont abuse the system to get coins etc.


**/
pragma solidity ^0.4.13;

import './TrialCoin.sol';
import "github.com/Arachnid/solidity-stringutils/strings.sol";
contract Tree {

    using strings for *;
    
    struct Distributor {
        address referrer;
        address distributor_add;
        bool isBanned;
        bool isInit;
        string disId;
        bytes32 childrenNo;
    }
    
    struct File {
        string link; // TODO: Decide on file hosting: where, how etc. IPFS?
        address committer;
        Distributor[] public distributors;
        boolean exists;
        uint256 balance;
    }
    
    // hash-map where bytes32 = id of file
    mapping(bytes32 => File) public files;

    //distrib map to check for bans
    mapping(address => Distributor) distributorMap;
    mapping(bytes32 => bool) outOfFunds;
    mapping(bytes32 => mapping(bytes32 => mapping(address => bool))) payed;
    address public owner;

    //the amount of funds attached to a contract that triggers a lowfund event
    uint256 threshold;
    //the rate of our token/eth
    uint256 coinRate;

    TrialCoin token;
    
    modifier isUnique(id) {
        require(!files[id].exists);
        __;
    }
    
    modifier onlyOwner() {
        require(owner == msg.sender);
        __;
    }
    
    event lowFunds(bytes32 id);

    event noFunds(bytes32 id);

    event checkForPayment(string disId);
    
    public Tree(uint256 rate, uint256 lowFundCap){

        owner = msg.sender;
        coinRate = rate;
        threshold = lowFundCap;
        token = createTokenContract();
        
    }
    
    function addFile(bytes32 id, string link, address original_distributor) payable onlyOwner isUnique(id) {
        // msg.sender is the committer
        // e.g. BBC

        //setup file info
        File file;
        file.link = link;
        file.committer = msg.sender;
        file.exists = true;
        file.balance = msg.value;*coinRate;

        //setup distributor info
        Distributor distributor;
        distributor.referrer = msg.sender;
        distributor.distributor_add = original_distributor;
        distributor.isBanned = false;
        distributor.isInit = true;
        distributor.disId = "0";
        distributor.childrenNo = 0;

        distributorMap[original_distributor] = distributor;
        //this might be problematic if you want original_distributor to be dynamic

        //store the data
        file.distributors.push(distributor);
        files[id] = file;
        
    }

    function topUp(bytes32 id) external payable onlyOwner{
        //not sure what to do with the ether that amasses on the contract
        topUpAmt = msg.value*coinRate;

        files[id].balance = files[id].balance + topUpAmt;

        
    }

    //this is called by the person who is already a distributor
    function addDistributor(bytes32 id, address invitee) external returns(bool){

        require(distributorMap[invitee].isBanned != false);

        require(distributorMap[invitee].isInit != true);


        if(outOfFunds[id] != true){

            Distributor distributor;
            distributor.referrer = msg.sender;
            distributor.distributor_add = invitee;
            distributor.isBanned = false;
            distributor.isInit = true;

            distributorMap[msg.sender].childrenNo = distributorMap[msg.sender].childrenNo + 1;

            distributor.childrenNo = 0;

            string memory childrenNoString = bytes32ToString(distributorMap[msg.sender].childrenNo);

            distributor.disId = distributorMap[msg.sender].disId.toSlice().concat(childrenNoString);

            distributorMap[invitee] = distributor;

            distributors.push(distributor);

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

        require(payed[fileId][disId][msg.sender] != true);

        string compare = disId.toSlice().find(distributorMap[msg.sender].disId.toSlice());

        if(equals(compare.toSlice(),disId.toSlice())){

            if(files[fileId].balance >=1){

                files[fileId].balance = files[fileId].balance -1;

                token.mint(msg.sender, 1);

                payed[fileId][disId][msg.sender] = true;

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

        return  files[id].link;

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

    function bytes32ToString (bytes32 data) internal returns (string) {
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