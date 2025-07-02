import { bcs, fromHex, toHex } from '@mysten/bcs'
import { Transaction } from '@mysten/sui/transactions'
import { config, MessageType, MessageVersion } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { ethers } from 'ethers'

export const approveTokenTransferAndClaim = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(
    process.env.ADMIN_PRIVATE_KEY || ''
  )
  const user = Ed25519Keypair.fromSecretKey(
    process.env.SUI_TEST_PRIVATE_KEY || ''
  )

  let source_chain = 4
  let sender_address = fromHex(process.env.EVM_USER_ADDRESS || '')
  let target_chain = 16
  let target_address = fromHex(user.getPublicKey().toSuiAddress())
  let token_type = 5
  let amount = 0.1 * 1e10
  let seq_num = 1

  const _tx = new Transaction()

  const [m] = _tx.moveCall({
    target: `${config.package()}::message::create_token_bridge_message`,
    arguments: [
      _tx.pure.u8(source_chain),
      _tx.pure.u64(seq_num),
      _tx.pure(bcs.vector(bcs.u8()).serialize(sender_address)),
      _tx.pure.u8(target_chain),
      _tx.pure(bcs.vector(bcs.u8()).serialize(target_address)),
      _tx.pure.u8(token_type),
      _tx.pure.u64(amount),
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
  //   console.log('_result:', _result)
  const bridgeMessage = new Uint8Array(_result.results[0].returnValues[0][0])

  //   const a = [
  //     bcs.u8().serialize(mt),
  //     bcs.u8().serialize(MessageVersion),
  //     bcs.u64().serialize(seq_num),
  //     bcs.u8().serialize(source_chain),
  //     bcs.vector(bcs.byteVector()).serialize([
  //         ...bcs.vector(bcs.u8()).serialize(sender_address).toBytes(),
  //         bcs.u8().serialize(target_chain),
  //         bcs.vector(bcs.u8()).serialize(target_address),
  //         bcs.u8().serialize(token_type),
  //         bcs.u64().serialize(amount),
  //     ]),
  //   ]

  const message_type_bytes = bcs
    .u8()
    .serialize(Number(MessageType.TOKEN_TRANSFER))
    .toBytes()
  const message_version_bytes = bcs.u8().serialize(MessageVersion).toBytes()
  const seq_num_bytes = bcs.u64().serialize(seq_num).toBytes()
  const source_chain_bytes = bcs.u8().serialize(source_chain).toBytes()
  const sender_address_bytes = bcs
    .vector(bcs.u8())
    .serialize(sender_address)
    .toBytes()
  const target_chain_bytes = bcs.u8().serialize(target_chain).toBytes()
  const target_address_bytes = bcs
    .vector(bcs.u8())
    .serialize(target_address)
    .toBytes()
  const token_type_bytes = bcs.u8().serialize(token_type).toBytes()
  const amount_bytes = bcs.u64().serialize(amount).toBytes()

  const payload = concatUint8Arrays([
    sender_address_bytes,
    target_chain_bytes,
    target_address_bytes,
    token_type_bytes,
    amount_bytes.reverse(),
  ])

  const source_message = concatUint8Arrays([
    message_type_bytes,
    message_version_bytes,
    seq_num_bytes.reverse(),
    source_chain_bytes,
    // new Uint8Array([payload.length]),
    payload,
  ])

  _result.results[1].returnValues[0][0] //   ) //   bcs.vector(bcs.byteVector()).serialize(
    .shift()
  console.log('Message: ', _result.results[0].returnValues[0][0])
  console.log('SerializeMessage: ', _result.results[1].returnValues[0][0])

  console.log('source_message:', toHex(source_message))
  //   return
  //   const serializeMessage = new Uint8Array(_result.results[1].returnValues[0][0])
  const serializeMessage = source_message
  console.log('SerializeMessage:', toHex(serializeMessage))
  const signatures = []
  for (let c of config.committees) {
    const signingKey = new ethers.SigningKey(c.privateKey())
    const signature = fromHex(
      signingKey.sign(ethers.keccak256(serializeMessage)).serialized
    )
    signatures.push(signature)
  }

  const [message] = tx.moveCall({
    target: `${config.package()}::message::create_token_bridge_message`,
    arguments: [
      tx.pure.u8(source_chain),
      tx.pure.u64(seq_num),
      tx.pure(bcs.vector(bcs.u8()).serialize(sender_address)),
      tx.pure.u8(target_chain),
      tx.pure(bcs.vector(bcs.u8()).serialize(target_address)),
      tx.pure.u8(token_type),
      tx.pure.u64(amount),
    ],
  })
  const _bridgeMessage = bcs.struct(
    `${config.package()}::message::BridgeMessage`,
    {
      message_type: bcs.u8(),
      message_version: bcs.u8(),
      seq_num: bcs.u64(),
      source_chain: bcs.u8(),
      payload: bcs.vector(bcs.u8()),
    }
  )
  //   const _bridgeMessageData = _bridgeMessage.serialize({
  //     message_type: Number(MessageType.TOKEN_TRANSFER),
  //     message_version: MessageVersion,
  //     seq_num: seq_num,
  //     source_chain: source_chain,
  //     payload: payload,
  //   })
  //   //   const bm = bcs
  //   //     .option(_bridgeMessage)
  //   //     .serialize(_bridgeMessage.parse(_bridgeMessageData.toBytes()))
  //   //     bcs.ge
  //   //   console.log(_bridgeMessage.toBytes())
  tx.moveCall({
    target: `${config.package()}::bridge::approve_token_transfer`,
    arguments: [
      tx.object(config.bridge()),
      message,
      bcs.vector(bcs.vector(bcs.u8())).serialize(signatures),
    ],
  })

  tx.moveCall({
    target: `${config.package()}::bridge::claim_and_transfer_token`,
    typeArguments: [config.sbtc_coin_type()],
    arguments: [
      tx.object(config.bridge()),
      tx.object('0x6'),
      tx.pure.u8(source_chain),
      tx.pure.u64(seq_num),
    ],
  })

  //   const result = await suiClient.devInspectTransactionBlock({
  //     transactionBlock: tx,
  //     sender: keypair.getPublicKey().toSuiAddress(),
  //   })
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })
  console.log('res:', result)
  // console.log('res:', result.results[0].mutableReferenceOutputs)
}

function concatUint8Arrays(arrays) {
  let totalLength = arrays.reduce((sum, arr) => sum + arr.length, 0) // 计算总长度
  let result = new Uint8Array(totalLength) // 创建目标数组
  let offset = 0

  for (let arr of arrays) {
    result.set(arr, offset) // 复制数据
    offset += arr.length
  }

  return result
}
