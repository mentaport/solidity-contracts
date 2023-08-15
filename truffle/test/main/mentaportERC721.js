const Web3 = require("web3");
const truffleAssert = require("truffle-assertions");
const MentaportERC721Contract = artifacts.require('MentaportERC721');

// The default MentaportERC721 mentaport_admin is same as owner of contract

contract('MentaportERC721 - Setup', function(accounts) {
  let instance = null;

  before(async () => {
    instance =  await MentaportERC721Contract.deployed();
  });

  it('should check contract setup', async() => {
    expect(
      web3.utils.isAddress(instance.address), "contract not deployed"
    ).to.be.true;

    expect(
      await instance.name(), "wrong token name"
    ).to.equal("mentaport");

    expect(
      (await instance.totalSupply()).toNumber(), "initial token supply is not zero"
    ).to.equal(0);
  });

});

contract('MentaportERC721 - Withdraw', function(accounts) {
  let instance = null;
  const admin = accounts[1];
  const tokenPath = 'ipfs://somepath/'

  before(async () => {
    instance =  await MentaportERC721Contract.deployed();
    await instance.unpause();
  });

  it('should fail when withdraw is not by owner', async() => {
    await truffleAssert.fails(
      instance.withdraw({from:admin}),
      truffleAssert.ErrorType.REVERT,
      "revert Ownable:"
    );
  });
});

contract('MentaportERC721 - Access Role Modifiers', function(accounts) {
  let instance = null;
  const owner = accounts[0];
  const admin = accounts[1];
  const minter = signer = accounts[2];
  const newMentaAcnt = "0x6a9b1C4742ee05701048e03149c2288b34AA1600";

  const userNewMinter = accounts[5];
  
  before(async () => {
    instance =  await MentaportERC721Contract.deployed();
  });

  it('should fail when unauthorized called tries to change mentaport account', async() => {
    await truffleAssert.fails(
      instance.changeMentaportAccount(newMentaAcnt,{from:admin}),
      truffleAssert.ErrorType.REVERT,
      "Caller is not mentaport"
    );
  });

  it('should change mentaport account by mentaport role', async() => {
    const res = await instance.changeMentaportAccount(newMentaAcnt, {from:owner});
    const log = res.logs[0];
  
    assert.equal(log.event, 'MentaportAccount');
    assert.equal(log.args.sender.toString(), owner);
    assert.equal(log.args.account.toString(), newMentaAcnt);
  });

  it('should check that contract main admin role set to only owner', async() => {
    const contract_role = await instance.CONTRACT_ROLE();
    const _admin = await instance.getRoleAdmin(contract_role);

    expect(await instance.hasRole(_admin, admin)).to.be.true;
    expect(await instance.hasRole(_admin, owner)).to.be.false;
  });

  it('should check if accounts have contract role', async() => {
    const contract_role = await instance.CONTRACT_ROLE();

    expect(await instance.hasRole(contract_role, admin)).to.be.true;
    expect(await instance.hasRole(contract_role, owner)).to.be.true;
  });

  it('should verify that owner and signer have the signer role', async() => {
    const signer_role = await instance.SIGNER_ROLE();

    expect(await instance.hasRole(signer_role, admin)).to.be.false;
    expect(await instance.hasRole(signer_role, owner)).to.be.true;
    expect(await instance.hasRole(signer_role, signer)).to.be.true;
  });

  it('should check if minter account has a minter role', async() => {
    const minter_role = await instance.MINTER_ROLE();
    expect(await instance.hasRole(minter_role, minter)).to.be.true;
  });

  it('should set a new minter role for the minter account', async() => {
    const minter_role = await instance.MINTER_ROLE()
    await instance.grantRole(minter_role, userNewMinter, {from: owner});
    const hasRole = await instance.hasRole(minter_role, userNewMinter);
    assert(hasRole, "Role was not set correctly for account");
  });

  it('should revoke minter role for minter account', async() => {
    const minter_role = await instance.MINTER_ROLE()
    await instance.revokeRole(minter_role, userNewMinter,{from: owner});
    
    const hasRole = await instance.hasRole(minter_role, userNewMinter);
    assert(!hasRole, "Role was not removed correctly for account");
  });

  it('should revoke ownership of contract', async() => {
    const contract_role = await instance.CONTRACT_ROLE();
    await instance.revokeRole(contract_role, admin, {from: admin})
    expect(await instance.hasRole(contract_role, admin)).to.be.false;
  });
});
