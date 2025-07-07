import { bcs, fromHex, toHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType } from './config'
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

export const executeAddTokensOnSUI = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(
    Buffer.from(config.admin(), 'hex') || ''
  )

  const __tx = new Transaction()

  const [tn] = __tx.moveCall({
    target: `0x1::type_name::get`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [],
  })
  __tx.moveCall({
    target: `0x1::type_name::into_string`,
    arguments: [tn],
  })

  const __result = await suiClient.devInspectTransactionBlock({
    transactionBlock: __tx,
    sender: keypair.getPublicKey().toSuiAddress(),
  })
  __result.results[1].returnValues[0][0].shift()
  console.log('result', __result.results[1].returnValues[0][0])
  let str = new Uint8Array(__result.results[1].returnValues[0][0])
  console.log(new TextDecoder('utf-8').decode(str))
  const token_types = []
  const supported_token_ids = []
  const token_prices = []
  for (let id in config.supported_chains) {
    for (let token of config.supported_chains[id]) {
      token_types.push(new Uint8Array(__result.results[1].returnValues[0][0]))
      supported_token_ids.push(token.token_id)
      token_prices.push(1)
    }
  }

  const _tx = new Transaction()
  const [seq_num] = _tx.moveCall({
    target: `${config.package()}::bridge::get_current_seq_num`,
    arguments: [
      _tx.object(config.bridge()),
      _tx.pure.u8(MessageType.ADD_TOKENS_ON_SUI),
    ],
  })
  const [m] = _tx.moveCall({
    target: `${config.package()}::message::create_add_tokens_on_sui_message`,
    arguments: [
      _tx.pure.u8(config.id),
      seq_num,
      _tx.pure.bool(false),
      _tx.pure.vector('u8', supported_token_ids),
      _tx.pure(bcs.vector(bcs.vector(bcs.u8())).serialize(token_types)),
      _tx.pure.vector('u64', token_prices),
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

  // return
  const bridgeMessage = new Uint8Array(_result.results[1].returnValues[0][0])
  console.log('bridgeMessage:', bridgeMessage)

  _result.results[2].returnValues[0][0].shift()
  const serializeMessage = new Uint8Array(_result.results[2].returnValues[0][0])
  console.log('serializeMessage:', serializeMessage)
  const signatures = []
  for (let c of config.committees) {
    const signingKey = new ethers.SigningKey(Buffer.from(c.privateKey(), 'hex'))
    const signature = fromHex(
      signingKey.sign(ethers.keccak256(serializeMessage)).serialized
    )
    signatures.push(signature)
    // tx.moveCall({
    //   target: `${config.package()}::committee::recover_signer`,
    //   arguments: [
    //     tx.pure(bridgeMessage),
    //     bcs.vector(bcs.u8()).serialize(signature),
    //   ],
    // })
  }

  const [message] = tx.moveCall({
    target: `${config.package()}::message::create_add_tokens_on_sui_message`,
    arguments: [
      tx.pure.u8(config.id),
      tx.pure.u64(0),
      tx.pure.bool(false),
      tx.pure.vector('u8', supported_token_ids),
      tx.pure(bcs.vector(bcs.vector(bcs.u8())).serialize(token_types)),
      tx.pure.vector('u64', token_prices),
    ],
  })
  tx.moveCall({
    target: `${config.package()}::bridge::execute_system_message`,
    arguments: [
      tx.object(config.bridge()),
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
  // console.log(
  //   'res:',
  //   toHex(new Uint8Array(result.results[0].returnValues[0][0]))
  // )
  // console.log(
  //   'res:',
  //   toHex(new Uint8Array(result.results[1].returnValues[0][0]))
  // )
  // console.log(
  //   'res:',
  //   toHex(new Uint8Array(result.results[2].returnValues[0][0]))
  // )
}
