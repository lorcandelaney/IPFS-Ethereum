/*My concerns:
1.) How do you insure that someone gives you the correct id? if you dont want to use ids as a means to find the file hash on the blockchain then how else will you find
them?

2.)No real way of insuring that people dont abuse the system to get coins etc.


**/
pragma solidity ^0.4.13;

import './TrialCoin.sol';
contract Tree {
    
    struct Distributor {
        address referrer;
        address distributor_add;
        bool isBanned;
        bool isInit;
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
    
    public Tree(uint256 rate, uint256 lowFundCap){

        owner = msg.sender;
        coinRate = rate;
        threshold = lowFundCap;
        token = createTokenContract();
        
    }
    
    function addFile(bytes32 id, string link, uint256 startBalance, address original_distributor) payable onlyOwner isUnique(id) {
        // msg.sender is the committer
        // e.g. BBC

        //setup file info
        File file;
        file.link = link;
        file.committer = msg.sender;
        file.exists = true;
        file.balance = startBalance;

        //setup distributor info
        Distributor distributor;
        distributor.referrer = msg.sender;
        distributor.distributor_add = original_distributor;
        distributor.isBanned = false;
        distributor.isInit = true;

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

    //this is called by the person receiving the file to host.
    function addDistributor(bytes32 id, address inviter) external returns(bool){

        require(distributorMap[msg.sender].isInit);

        require(distributorMap[inviter].isBanned == false);


        if(files[id].balance >=1){

            Distributor distributor;
            distributor.referrer = inviter;
            distributor.distributor_add = msg.sender;
            distributor.isBanned = false;
            distributor.isInit = true;

            distributorMap[distributor] = msg.sender;

            distributors.push(distributor);
            files[id].balance = files[id].balance -1;

            //could update this to draw from a finite pool set by contract creator
            token.mint(inviter, 1);

            return true;
        }

        else{
            noFunds(id);
            return false;
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
}