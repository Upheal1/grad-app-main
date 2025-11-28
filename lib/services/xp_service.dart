import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class XPService {
  final String rpcUrl = "http://127.0.0.1:7545"; // Ganache
  final String privateKey = "<PRIVATE_KEY_FROM_GANACHE>";
  final String contractAddress = "<DEPLOYED_CONTRACT_ADDRESS>";
  late Web3Client client;
  late Credentials credentials;
  late DeployedContract contract;
  late ContractFunction addEventFunction;
  late ContractFunction getEventsFunction;

  XPService() {
    client = Web3Client(rpcUrl, Client());
    credentials = EthPrivateKey.fromHex(privateKey);
    _loadContract();
  }

  Future<void> _loadContract() async {
    String abiString = await rootBundle.loadString("assets/XPTracker.json");
    final abi = jsonDecode(abiString) as Map<String, dynamic>;
    contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi['abi']), "XPTracker"),
      EthereumAddress.fromHex(contractAddress),
    );
    addEventFunction = contract.function('addEvent');
    getEventsFunction = contract.function('getEvents');
  }

  Future<String> addEvent(String description) async {
    final result = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: addEventFunction,
        parameters: [description],
      ),
      chainId: 1337, // Ganache
    );
    return result;
  }

  Future<List<dynamic>> getEvents() async {
    final myAddress = await credentials.extractAddress(); // العنوان الصحيح
    final events = await client.call(
      contract: contract,
      function: getEventsFunction,
      params: [myAddress], // مهم جداً، لا تستخدم "4" أو أي رقم
    );
    return events[0];
  }
}
