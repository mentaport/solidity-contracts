const truffleAssert = require("truffle-assertions");
const Web3 = require("web3");
const MentaportMintContract = artifacts.require('MentaportMint');

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

contract('MentaportMint - Setup', function(accounts) {
  let signer;
  let instance = null;
  const userMinter = accounts[2];
  const tokenPath = 'ipfs://somepath/'

  before(async () => {
    instance =  await MentaportMintContract.deployed();
    await instance.useUseMintRules(false);

    signer = await web3.eth.accounts.create();
  });

  it('should check contract setup', async() => {
    expect(
      web3.utils.isAddress(instance.address), "contract not deployed"
    ).to.be.true;

    expect(
      await instance.name(), "wrong token name"
    ).to.equal("mentaport Mint");

    expect(
      (await instance.totalSupply()).toNumber(), "initial token supply is not zero"
    ).to.equal(0);
  });

  it("should check pause/unpause states", async () => {
    await truffleAssert.fails(
      instance.mint(tokenPath, {value: web3.utils.toWei('0.001',"ether")}),
      truffleAssert.ErrorType.REVERT,
      "Pausable: paused"
    );

    await truffleAssert.fails(
      instance.unpause({from:userMinter}),
      truffleAssert.ErrorType.REVERT,
      "Caller is not contract admin"
    );

    await instance.unpause();
    expect(
      await instance.paused(), "contract is still paused"
    ).to.be.false;

    await truffleAssert.fails(
        instance.unpause(),
      truffleAssert.ErrorType.REVERT,
      "Pausable: not paused"
    );

    await instance.pause();
    expect(
      await instance.paused(), "contract is still unpaused"
    ).to.be.true;

    await truffleAssert.fails(
      instance.pause(),
      truffleAssert.ErrorType.REVERT,
      "Pausable: paused"
    );
  });
});

contract('MentaportMint - Mint', function(accounts) {
  let instance = null;
  let contractAddress;
  const userA = accounts[1];
  const userB = accounts[2];
  const notOwner = accounts[5];
  const tokenPath = 'ipfs://somepath/'

  before(async () => {
    instance =  await MentaportMintContract.deployed();
    contractAddress = instance.address;
    await instance.useUseMintRules(false);
    await instance.unpause();

  });

  it('should fail to mint when funds are insufficient', async() => {
    await truffleAssert.fails(
      instance.mint(tokenPath, {value: web3.utils.toWei('0.0001',"ether")}),
      truffleAssert.ErrorType.REVERT,
      "Insufficient funds"
    );
  });
  it('should fail to mint nft with location because not using rules', async() => {  
    const locationRuleId = 1;
    const timestamp = testTime(0);
    const receiver = (await web3.eth.accounts.create()).address;
    const hash = hashMessage(contractAddress, receiver, timestamp, locationRuleId);
    
    let  signer = await web3.eth.accounts.create();
    signer_role = await instance.SIGNER_ROLE();
    await instance.grantRole(signer_role, signer.address,{from: userA});
    const signature = signer.sign(hash);

    const mintRequest = {
      signature: signature.signature,
      locationRuleId: locationRuleId,
      timestamp: timestamp,
      receiver: receiver,
      tokenURI: tokenPath,
    }
    await truffleAssert.fails(
      instance.mintLocation(mintRequest, {value: web3.utils.toWei('0.001',"ether")}),
      truffleAssert.ErrorType.REVERT,
      "Failed not using mint rules, use normal mint function."
    );
  });

  it('should mint 1 nft to owner', async() => {
    const numMint = 1;
    const currentSupply = (await instance.totalSupply()).toNumber();
    const tokenURL = tokenPath + "12334/metadata.json"
    await instance.mint(tokenURL, {value: web3.utils.toWei('0.001',"ether")});
    const totalSupply = (await instance.totalSupply()).toNumber();
    expect(currentSupply + numMint).to.equal(totalSupply);
  });

  it('should mint 1 nft to non-owner', async() => {
    const numMint = 1;
    const currentSupply = (await instance.totalSupply()).toNumber();
    const tokenURL = tokenPath + "456789/metadata.json"
    await instance.mint(tokenURL, {from: userB, value: web3.utils.toWei('0.001',"ether")});
    const totalSupply = (await instance.totalSupply()).toNumber();
    expect(currentSupply + numMint).to.equal(totalSupply);
  });

  it('should fail to `mintForAddress` if caller is not minter', async() => {
    await truffleAssert.fails(
      instance.mintForAddress(tokenPath, userB, {from: notOwner}),
      truffleAssert.ErrorType.REVERT,
      "Caller is not minter"
    );
  });

  it('should allow `mintForAddress` if caller is minter', async() => {
    const numMint = 1;
    const currentSupply = (await instance.totalSupply()).toNumber();
    const tokenURL = tokenPath + "09876/metadata.json"
    await instance.mintForAddress(tokenURL, userB, {from:userB});
    const totalSupply = (await instance.totalSupply()).toNumber();
    expect(currentSupply + numMint).to.equal(totalSupply);
  });

  it('should return correct tokenURI for tokenID 1:', async() => {
    let tokenId = 1;
    const expectedtokenUrl = tokenPath + "12334/metadata.json"
    expect(await instance.tokenURI(tokenId)).to.equal(expectedtokenUrl);
  });

  it('should return correct tokenURI for tokenID 2:', async() => {
    let tokenId = 2;
    const expectedtokenUrl = tokenPath + "456789/metadata.json"
    expect(await instance.tokenURI(tokenId)).to.equal(expectedtokenUrl);
  });
  
  it('should return correct tokenURI for tokenID 2 after updating:', async() => {
    let tokenId = 2;
    const expectedtokenUrl = tokenPath + "456789/metadata.json"
    expect(await instance.tokenURI(tokenId)).to.equal(expectedtokenUrl);
    // update tokenURI
    const newtokenUrl = tokenPath + "50000/metadata.json"
    await instance.updateTokenURI(tokenId,newtokenUrl);

    expect(await instance.tokenURI(tokenId)).to.equal(newtokenUrl);
  });

  it('should fail to update tokenURI, wrong role:', async() => {
    let tokenId = 1;
    const newtokenUrl = tokenPath + "50000/metadata.json"
    await truffleAssert.fails(
      instance.updateTokenURI(tokenId,newtokenUrl, {from: notOwner}),
      truffleAssert.ErrorType.REVERT,
      "Caller is not contract admin"
    );   
  });

  it('should fail to update tokenURI, wrong tokenId:', async() => {
    let tokenId = 100;
    const newtokenUrl = tokenPath + "50000/metadata.json"
    await truffleAssert.fails(
      instance.updateTokenURI(tokenId,newtokenUrl, ),
      truffleAssert.ErrorType.REVERT,
      "ERC721URIStorage: URI set of nonexistent token"
    );   
  });

  it('should fail when withdraw is not by owner', async() => {
    await truffleAssert.fails(
      instance.withdraw({from: notOwner}),
      truffleAssert.ErrorType.REVERT,
      "revert Ownable:"
    );
  });
});

contract('MentaportMint - MintLocation', function(accounts) {
  let contractAddress, signer, randomSigner, signer_role;
  let instance = null;
  const owner = accounts[0];
  const userA = accounts[1];
  const userB = accounts[2];
  const notOwner = accounts[5];

  const tokenURI = 'ipfs://somepath/'
  const timestamp = testTime(0);

  before(async () => {
    instance =  await MentaportMintContract.deployed();
    contractAddress = instance.address;
    randomSigner = await web3.eth.accounts.create();
    await instance.unpause();

    signer = await web3.eth.accounts.create();
    signer_role = await instance.SIGNER_ROLE();
    await instance.grantRole(signer_role, signer.address,{from: userA});
  });

  it('should fail to mint when funds are insufficient', async() => {
    await truffleAssert.fails(
      instance.mint(tokenURI, {value: web3.utils.toWei('0.0001',"ether")}),
      truffleAssert.ErrorType.REVERT,
      "Insufficient funds"
    );
  });

  it('should fail to mint nft because using location rules', async() => {  
    await truffleAssert.fails(
      instance.mint(tokenURI, {value: web3.utils.toWei('0.001',"ether")}),
      truffleAssert.ErrorType.REVERT,
      "Failed using mint rules, use mintLocation."
    );
  });

  it("should fail to mint with invalid location rules id", async ()=> {
    const locationRuleId = 34;
    const locationRuleIdWrong = 35;
    const receiver = (await web3.eth.accounts.create()).address;
    const hash = hashMessage(contractAddress, receiver, timestamp, locationRuleId);
    const signature = signer.sign(hash);

    const mintRequest = {
      signature: signature.signature,
      locationRuleId:locationRuleIdWrong,
      timestamp: timestamp,
      receiver: receiver,
      tokenURI: tokenURI
    }

    await truffleAssert.fails(
      instance.mintLocation(mintRequest, {
        value: web3.utils.toWei('0.001',"ether")
      }),
      truffleAssert.ErrorType.REVERT,
      "Invalid signer"
    );
  });

  it("should fail to mint with wrong signature", async ()=> {
    const locationRuleId = 2;
    const receiver = (await web3.eth.accounts.create()).address;
    //signer = await web3.eth.accounts.create();
    const hash = hashMessage(contractAddress, receiver, timestamp, locationRuleId);
    const signature = randomSigner.sign(hash);

    const mintRequest = {
      signature: signature.signature,
      timestamp: timestamp,
      receiver: receiver,
      tokenURI: tokenURI,
      locationRuleId
    }

    await truffleAssert.fails(
      instance.mintLocation(mintRequest, {
        from:userA, value: web3.utils.toWei('0.001',"ether")
      }),
      truffleAssert.ErrorType.REVERT,
      "revert Invalid signer"
    );
  });

  it("should mint with right location rule id and signature", async ()=> {
    const locationRuleId = 1;
    const receiver = (await web3.eth.accounts.create()).address;
    const hash = hashMessage(contractAddress, receiver, timestamp, locationRuleId);
    const signature = signer.sign(hash);

    const mintRequest = {
      signature: signature.signature,
      locationRuleId: locationRuleId,
      timestamp: timestamp,
      receiver: receiver,
      tokenURI: tokenURI,
    }
    const tx = await instance.mintLocation( mintRequest, {
      value: web3.utils.toWei('0.001',"ether")
    })
    const minterBalance = await instance.balanceOf(receiver);
    expect(minterBalance.toNumber()).to.equal(1);
    truffleAssert.eventEmitted(tx, 'MintLocation', event => {
      return (
        event.tokenId.toNumber() >= 0
      );
    });
  })

  it('should fail when withdraw is not by owner', async() => {
    await truffleAssert.fails(
      instance.withdraw({from: notOwner}),
      truffleAssert.ErrorType.REVERT,
      "revert Ownable:"
    );
  });
});


contract('MentaportMint - Role Functions', function(accounts) {
  let instance;

  const owner = accounts[0];
  const userAdmin = accounts[1];
  const userMinter = accounts[2];
  const mentaportAccount = "0x163f3475D1C4F194BD381B230a543DAA8D3f7c0d";

  before(async () => {
    instance =  await MentaportMintContract.deployed();
    await instance.useUseMintRules(false);
    await instance.unpause();

    signer = await web3.eth.accounts.create();
  });

 
  it('should withdraw rewards', async() => {
    const mentaportBalanceBefore = await web3.eth.getBalance(mentaportAccount);
  
 
    await instance.mint(1, {from: userAdmin, value: web3.utils.toWei('0.001',"ether")});
   
    const contractBalance =  await web3.eth.getBalance(instance.address)
    const ownerBalanceBefore = await web3.eth.getBalance(owner);
    await instance.withdraw();

    const ownerBalanceAfter = await web3.eth.getBalance(owner);
    const mentaportBalanceAfter = await web3.eth.getBalance(mentaportAccount);

    expect(mentaportBalanceAfter - mentaportBalanceBefore).to.equal((25 * contractBalance) / 1000);
    expect(ownerBalanceAfter - ownerBalanceBefore).to.be.at.least((75 * contractBalance) / 1000);
  });
});

