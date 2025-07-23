import { bcs, fromHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { ethers } from 'ethers'

export const updateBridgeFeePercentage = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')

  const _tx = new Transaction()
  _tx.moveCall({
    target: `${config.package()}::bridge::get_current_seq_num`,
    arguments: [
      _tx.object(config.bridge()),
      _tx.pure.u8(MessageType.UPDATE_BRIDGE_FEE_PERCENTAGE),
    ],
  })

  const _result = await suiClient.devInspectTransactionBlock({
    transactionBlock: _tx,
    sender: keypair.getPublicKey().toSuiAddress(),
  })

  const [message] = tx.moveCall({
    target: `${config.package()}::message::create_update_bridge_fee_percentage_message`,
    arguments: [
      tx.pure.u8(config.id),
      tx.pure.u64(_result.results[0].returnValues[0][0].shift()),
      tx.pure.u8(1),
      tx.pure.u8(1),
      tx.pure.u64(0),
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
