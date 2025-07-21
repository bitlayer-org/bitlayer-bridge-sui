import { bcs, fromHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { ethers } from 'ethers'

export const executeUpdateBridgeLimit = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')
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
  _tx.moveCall({
    target: `${config.package()}::bridge::get_current_seq_num`,
    arguments: [
      _tx.object(config.bridge()),
      _tx.pure.u8(MessageType.UPDATE_BRIDGE_LIMIT),
    ],
  })

  const _result = await suiClient.devInspectTransactionBlock({
    transactionBlock: _tx,
    sender: keypair.getPublicKey().toSuiAddress(),
  })


  // const bridgeMessage = new Uint8Array(_result.results[1].returnValues[0][0])

  // _result.results[2].returnValues[0][0].shift()
  // const serializeMessage = new Uint8Array(_result.results[2].returnValues[0][0])
  // const signatures = []
  // for (let c of config.committees) {
  //   const signingKey = new ethers.SigningKey(Buffer.from(c.privateKey(), 'hex'))
  //   const signature = fromHex(
  //     signingKey.sign(ethers.keccak256(serializeMessage)).serialized
  //   )
  //   signatures.push(signature)
  // }

  /**
   * source_chain_id: u8,
        seq_num: u64,
        sending_chain: u8,
        sending_token: u8,
        new_limit: u64,
   */
  const [message] = tx.moveCall({
    target: `${config.package()}::message::create_update_bridge_limit_message`,
    arguments: [
      tx.pure.u8(config.id),
      tx.pure.u64(_result.results[0].returnValues[0][0].shift()),
      tx.pure.u8(250),
      tx.pure.u8(88),
      tx.pure.u64(0.1 * 10 ** 8),
    ],
  })
  tx.moveCall({
    target: `${config.package()}::bridge::execute_system_message`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      message,
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
