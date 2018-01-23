
    /* Configuration variables */
    var ipfsHost    = 'localhost';
    var ipfsAPIPort = '5001';
    var ipfsWebPort = '8080';
    var web3Host    = 'http://localhost';
    var web3Port    = '8545';

    /* IPFS initialization */
    var ipfs = window.IpfsApi(ipfsHost, ipfsAPIPort)
    ipfs.swarm.peers(function (err, res) {
        if (err) {
            console.error(err);
        } else {
            var numPeers = res.Peers === null ? 0 : res.Peers.length;
            console.log("IPFS - connected to " + numPeers + " peers");
        }
    });

    /* web3 initialization */
    var Web3 = require('web3');
    var web3 = new Web3();
    web3.setProvider(new web3.providers.HttpProvider(web3Host + ':' + web3Port));
    if (!web3.isConnected()) {
        console.error("Ethereum - no connection to RPC server");
    } else {
        console.log("Ethereum - connected to RPC server");
    }
    
    //TODO: REPLACE WITH OUR ABI
    var contractInterface = [{
        "constant": false,
        "inputs": [{
	        "name": "x",
	        "type": "string"
        }],
        "name": "set",
        "outputs": [],
        "type": "function"
    }, {
        "constant": true,
        "inputs": [],
        "name": "get",
        "outputs": [{
	        "name": "x",
	        "type": "string"
        }],
        "type": "function"
    }];

    var account = web3.eth.accounts[0];


    var sendDataObject = {
        from: account,
        gas: 300000,
    };

    window.ipfs = ipfs;
    window.web3 = web3;
    window.account = account;
    window.contractObject = contractObject;
    window.contract = web3.eth.contract(contractInterface);
    window.ipfsAddress = "http://" + ipfsHost + ':' + ipfsWebPort + "/ipfs";

   //TODO:CONNECT TO CONTRACT


   //TODO: INERGRATE OUR CONTRACT
    function storeContent(url) {
        window.ipfs.add(url, function(err, result) {
            if (err) {
                console.error("Content submission error:", err);
                return false;
            } else if (result && result[0] && result[0].Hash) {
                console.log("Content successfully stored. IPFS address:", result[0].Hash);
            } else {
                console.error("Unresolved content submission error");
                return null;
            }
        });
    }
    //TODO: INERGRATE OUR CONTRACT
    function storeAddress(data) {
        if (!window.contractInstance) {
            console.error('Ensure the storage contract has been deployed');
            return;
        }

        if (window.currentData == data) {
            console.error("Overriding existing data with same data");
            return;
        }

        window.contractInstance.set.sendTransaction(data, window.sendDataObject, function (err, result) {
            if (err) {
                console.error("Transaction submission error:", err);
            } else {
                window.currentData = data;
                console.log("Address successfully stored. Transaction hash:", result);
            }
        });
    }
    //TODO:INERGRATE OUR CONTRACT
    function fetchContent() {
        if (!window.contractInstance) {
            console.error("Storage contract has not been deployed");
            return;
        }

        window.contractInstance.get.call(function (err, result) {
            if (err) {
                console.error("Content fetch error:", err);
            } else if (result && window.IPFSHash == result) {
                console.log("New data is not mined yet. Current data: ", result);
                return;
            } else if (result) {
                window.IPFSHash = result;
                var URL = window.ipfsAddress + "/" + result;
                console.log("Content successfully retrieved. IPFS address", result);
                console.log("Content URL:", URL);
            } else {
                console.error('No data, verify the transaction has been mined');
            }
        });
    }

    function getBalance() {
        window.web3.eth.getBalance(window.account, function (err, balance) {
            console.log(parseFloat(window.web3.fromWei(balance, "ether")));
        });
    }