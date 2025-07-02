import { bcs, fromHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType, MessageVersion } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { ethers } from 'ethers'

export const AddRoutesOnSui = bcs.struct('AddRoutesOnSui', {
  supported_chain_ids: bcs.vector(bcs.u8()),
  supported_token_ids: bcs.vector(bcs.u8()),
  fee_percentages: bcs.vector(bcs.u64()),
  bridge_amounts: bcs.vector(bcs.u64()),
  supporteds: bcs.vector(bcs.bool()),
})

export const executeAddRoutesOnSUI = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(
    process.env.ADMIN_PRIVATE_KEY || ''
  )
  const supported_chain_ids = []
  const supported_token_ids = []
  const fee_percentages = []
  const bridge_amounts = []
  const supporteds = []
  for (let id in config.supported_chains) {
    for (let token of config.supported_chains[id]) {
      supported_chain_ids.push(id)
      supported_token_ids.push(token.token_id)
      fee_percentages.push(token.fee_percentage)
      bridge_amounts.push(token.bridge_amount)
      supporteds.push(token.supported)
    }
  }

  const _tx = new Transaction()
  const [seq_num] = _tx.moveCall({
    target: `${config.package()}::bridge::get_current_seq_num`,
    arguments: [
      _tx.object(config.bridge()),
      _tx.pure.u8(MessageType.ADD_ROUTES_ON_SUI),
    ],
  })
  const [m] = _tx.moveCall({
    target: `${config.package()}::message::create_add_routes_on_sui_message`,
    arguments: [
      _tx.pure.u8(config.id),
      seq_num,
      _tx.pure.vector('u8', supported_chain_ids),
      _tx.pure.vector('u8', supported_token_ids),
      _tx.pure.vector('u64', fee_percentages),
      _tx.pure.vector('u64', bridge_amounts),
      _tx.pure.vector('bool', supporteds),
    ],
  })
  _tx.moveCall({
    target: `${config.package()}::message::serialize_message`,
    arguments: [m],
  })

  const _result = await suiClient.devInspectTransactionBlock({
    transactionBlock: _tx,
    sender: keypair.getPublicKey().toSuiAddress(),
  })

  const bridgeMessage = new Uint8Array(_result.results[1].returnValues[0][0])

  _result.results[2].returnValues[0][0].shift()
  const serializeMessage = new Uint8Array(_result.results[2].returnValues[0][0])
  const signatures = []
  for (let c of config.committees) {
    const signingKey = new ethers.SigningKey(c.privateKey())
    const signature = fromHex(
      signingKey.sign(ethers.keccak256(serializeMessage)).serialized
    )
    signatures.push(signature)
  }

  const [message] = tx.moveCall({
    target: `${config.package()}::message::create_add_routes_on_sui_message`,
    arguments: [
      tx.pure.u8(config.id),
      tx.pure.u64(0),
      tx.pure.vector('u8', supported_chain_ids),
      tx.pure.vector('u8', supported_token_ids),
      tx.pure.vector('u64', fee_percentages),
      tx.pure.vector('u64', bridge_amounts),
      tx.pure.vector('bool', supporteds),
    ],
  })
  tx.moveCall({
    target: `${config.package()}::bridge::execute_system_message`,
    arguments: [
      tx.object(config.bridge()),
      // _bridgeMessage,
      message,
      bcs.vector(bcs.vector(bcs.u8())).serialize(signatures),
    ],
  })

  // const result = await suiClient.devInspectTransactionBlock({
  //   transactionBlock: tx,
  //   sender: keypair.getPublicKey().toSuiAddress(),
  // })
  tx.setGasBudget(13299524)
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })
  console.log('res:', result)
  // console.log('res:', result.results[0].mutableReferenceOutputs)
}
