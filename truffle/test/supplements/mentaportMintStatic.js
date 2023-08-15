const truffleAssert = require("truffle-assertions");
const MentaportMintContract = artifacts.require('MentaportMintStatic');

function testTime(min) {
    var dateInSecs = Math.floor(new Date().getTime() / 1000);
    const addMin =  min * 60
    dateInSecs += addMin
    return dateInSecs;
}

function hashMessage(address, account, timestamp, rule) {
    const hashedMessage = web3.utils.soliditySha3(address,account,timestamp, rule);
    return hashedMessage;
}

contract('MentaportMintStatic - signature tests', function(accounts) {
    let instance = null;
    let contractAddress;
    let numMint = 1;

    const owner = accounts[0];
    const userA = accounts[1];
    const userB = accounts[2];
    const timestamp = testTime(0);
    
    before(async () => {
        instance =  await MentaportMintContract.deployed();
        contractAddress = instance.address;
        await instance.unpause();

        signer = await web3.eth.accounts.create();
    });
   
    it('should fail to mint using mint function when rules are enabled', async() => {
        await truffleAssert.fails(
          instance.mint(numMint, {value: web3.utils.toWei('0.001',"ether")}),
          truffleAssert.ErrorType.REVERT,
          "Failed using mint rules, use mintMenta."
        );
    });

    it('should fail to mint with wrong hash', async() => {
        const mintAmount = 1;
        const rule = 0;
        const hash = hashMessage('some random account',userB, timestamp, rule);
        const signature = signer.sign(hash);

        await truffleAssert.fails(
          instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
              value: web3.utils.toWei('0.001',"ether")
          }),
          truffleAssert.ErrorType.REVERT,
          "revert Wrong signature"
        );
    });

    it('should fail to mint with wrong signer', async() => {
        const mintAmount = 1;
        const rule = 0;
        const hash = hashMessage(contractAddress, owner, timestamp, rule);
        const signature = signer.sign(hash);

        await truffleAssert.fails(
          instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
              value: web3.utils.toWei('0.001',"ether")
          }),
          truffleAssert.ErrorType.REVERT,
          "revert Wrong signature"
        );
    });

    it('should fail to grant signer role by wrong admin', async() => {
        const signer_role = await instance.SIGNER_ROLE();
        await truffleAssert.fails(
          instance.grantRole(signer_role, signer.address, {from:userB}),
          truffleAssert.ErrorType.REVERT,
          "missing role"
        );
    });

    it('should mint with correct hash and signer', async() => {
        const mintAmount = 1;
        const rule = 0;
        const hash = hashMessage(contractAddress, owner, timestamp, rule);
        const signature = signer.sign(hash);

        const signer_role = await instance.SIGNER_ROLE();
        await instance.grantRole(signer_role, signer.address, {from: userA});
        const mint = await instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
            value: web3.utils.toWei('0.001',"ether")
        });
       
        expect(mint.receipt.status).to.be.true;
    });

    it('should fail to mint with a used signature', async() => {
        const mintAmount = 1;
        const rule = 0;
        const hash = hashMessage(contractAddress, owner, timestamp, rule);
        const signature = signer.sign(hash);
        await truffleAssert.fails(
          instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
              value: web3.utils.toWei('0.001',"ether")
          }),
          truffleAssert.ErrorType.REVERT,
          "revert Signature already used"
        );
    });

    it('should mint with correct hash and signer', async() => {
        const mintAmount = 1;
        const rule = 1;
        const hash = hashMessage(contractAddress, owner, timestamp, rule);
        const signature = signer.sign(hash);
        const signer_role = await instance.SIGNER_ROLE();
        await instance.grantRole(signer_role, signer.address, {from: userA});

        const mint = await instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
            value: web3.utils.toWei('0.001',"ether")
        });
       
        expect(mint.receipt.status).to.be.true;
    });

    it('should fail to mint when sender is not signer', async() => {
        const mintAmount = 1;
        const rule = 2;
        const hash = hashMessage(contractAddress, owner, timestamp, rule);
        const signature = signer.sign(hash);

        await truffleAssert.fails(
          instance.mintLocation(mintAmount, rule, timestamp, signature.signature, {
              from:userA, value: web3.utils.toWei('0.001',"ether")
          }),
          truffleAssert.ErrorType.REVERT,
          "revert Wrong signature"
        );
    });
});


