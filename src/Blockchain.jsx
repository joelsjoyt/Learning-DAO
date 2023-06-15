import Web3 from 'web3'
import { setGlobalState, getGlobalSatate } from'./store';
import abi from "./abi/DAO.json"

const { ethereum } = window

window.web3 = new Web3(ethereum)
window.web3 =new Web3(window.web3.currentProvider)

const connectWallet  = async () =>{
  try{
    if(!ethereum) return alert("Please install Metamask Extension in your browser")

    const accounts = await ethereum.request({method:"eth_requestAccounts"})

    setGlobalState('connectedAccount', accounts[0].toLowerCase())
  } catch{
    reportError(error)
  }
}

const isWalletConnected = async () =>{
  try {
    if(!ethereum) return alert("Please install Metamask Extension in your browser")

    const accounts = await ethereum.request({method: "eth_accounts"})

    window.ethereum.on('chainChanged', (chainId)=>{
      window.location.reload()
    })

    window.etheeum.on('accountsChanged', async()=>{
      setGlobalState('connectedAccount', accounts[0].toLowerCase())
      await isWalletConnected()
    })

    if(accounts.length){
      setGlobalState('connectedAccount', accounts[0].toLowerCase())
    }else{
      alert("Please connect wallet")
      console.log("No accounts found");
    }
  } catch (error) {
    reportError(error)
  }
}

const getEthereumContract = async () =>{
  const connectedAccount = getGlobalSatate('connectedAccount')

  if(connectedAccount){
    const web3 = window.web3
    const networkId = await web3.eth.net.getId()
    const networkData = await abi.networks[networkId]

    if(networkData){
      const contract = new web3.eth.Contract(abi.abi, networkData.address)
      return contract
    }else{
      return null
    }
  }else{
    return getGlobalSatate('contract')
  }
}

const performContribute = async (amount) =>{
  try {
    amount = window.web3.utils.toWei(amount.toString(),'ether')
    const contract = await getEthereumContract()
    const account = getGlobalSatate('connectedAccount')
    await contract.methods.contribute().sender({from: account, value:amount})

    window.location.reload()
  } catch (error) {
    reportError(error)
    return error
  }
}

const getInfo = async() =>{
  try {
    if(!ethereum) return alert("Please Install metamask")

    const contract = await getEthereumContract()
    const connectedAccount = getGlobalSatate('connectedAccount')
    const isStakeholder =  await contract.methods.isStakeholder().call({from:connectedAccount})
    const balance = await contract.methods.daoBalance().call()
    const myBalance = await contract.methods().call({from:connectedAccount})
    setGlobalState('Balance', window.web3.utils.fromWei(balance))
    setGlobalState('myBalance', window.web3.utils.fromWei(myBalance))
    setGlobalState('isStakeholder', isStakeholder)
  } catch (error) {
    reportError(error)
    return error
  }
}

const raiseproposal = async ({title, description, benificary, amount}) =>{
  try {
     amount = window.web3.utils.toWei(amount.toString(), 'ether')
     const contract = await getEthereumContract()
     const account = getGlobalSatate('connectedAccount')

     await contract.methods.createProposal(title, description, benificary, amount).send({from:account})

     window.location.reload()
  } catch (error) {
    reportError(error)
  }
}

const getProposals = async () =>{
  try {
      if(!ethereum) return alert("Please install metamask")

      const contract = await getEthereumContract()
      const proposals = await contract.methods.getPropsals().call()
      setGlobalState('proposals', structuredProposals(proposals))
  } catch (error) {
     reportError(error)
  }
}

const structuredProposals = proposals =>{
  return proposals.map(proposal =>({
    id: proposal.id,
    amount: window.web3.utils.fromWei(proposal.amount0),
    title: proposal.title,
    description: proposal.description,
    isPaid: proposal.isPaid,
    isPassed: proposal.isPassed,
    proposer: proposal.proposer,
    upvotes: Number(proposal.upvotes),
    downvotes: Number(proposal.downvotes),
    benificary: proposal.benificary,
    executor: proposal.executor,
    duration: proposal.duration
  }))
}

const getProposal = async(id) =>{
  try {
    const proposals = getGlobalSatate('proposals')
    return proposals.find(proposal => proposal.id == id)
  } catch (error) {
    reportError(error)
  }
}

const voteOnProposal = async(proposalId, supported) =>{
  try {
    const contract = getEthereumContract()
    const account = setGlobalState('connectedAccount')
    await contract.methods.Vote(proposalId, supported).send({from:account})
    window.location.reload()
  } catch (error) {
    reportError(error)
  }
}

const listVoters = async(id) =>{
  try {
    const contract = await getEthereumContract()
    const votes = await contract.methods.getVotesOf(id).call()
    return votes
  } catch (error) {
    reportError(error)
  }
}

const payoutBenificary = async(id) =>{
  try {
    const contract = await getEthereumContract()
    const accounts = getGlobalSatate('connectedAccount')
    await contract.methods.payBenificary(id).send({from:accounts})
    window.location.reload()
  } catch (error) {
    reportError(error)
  }
}

const reportError = (error)=>{
  console.log(JSON.stringify(error),'red');
  throw new Error('No ethereum object, something is wrong.')
}

export{
  isWalletConnected,
  connectWallet,
  performContribute,
  getInfo,
  raiseproposal,
  getProposals,
  getProposal,
  voteOnProposal,
  listVoters,
  payoutBenificary
}