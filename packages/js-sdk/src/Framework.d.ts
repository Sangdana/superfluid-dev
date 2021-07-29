import type Web3 from "web3";
import { ethers, Contract as EthersContract, utils } from "ethers";
import type { Contract as Web3Contract } from "web3-eth-contract";
import TruffleContract from "@truffle/contract";

import ConstantFlowAgreementV1Helper from "./ConstantFlowAgreementV1Helper";
import InstantDistributionAgreementV1Helper from "./InstantDistributionAgreementV1Helper";
import GasMeter from "./utils/gasMetering/gasMetering";
import LoadContracts from "./loadContracts";
import Config from "./getConfig";
import User from "./User";
import Utils from "./Utils";

declare type GasReportTypeOptions = 'JSON' | 'HTML' | 'TENDERLY';

export declare interface Agreements {
    cfa?: ConstantFlowAgreementV1Helper,
    ida?: InstantDistributionAgreementV1Helper
}

export interface FrameworkOptions {
    version?: string,
    isTruffle: boolean,
    web3?: Web3,
    ethers?: LoadContracts.EthersWithSigner,
    gasReportType: GasReportTypeOptions,
    additionalContracts?: string[],
    tokens?: string[],
    loadSuperNativeToken?: boolean,
    contractLoader?: LoadContracts.ContractLoader,
    resolverAddress?: string,
}
declare class Framework {

    constructor(options: FrameworkOptions);

    _options: FrameworkOptions;
    version: string;
    web3: Web3;
    ethers: LoadContracts.EthersWithSigner;
    _gasReportType: GasReportTypeOptions;
    config: Config.NetworkConfig;
    contracts: Promise<LoadContracts.LoadedContract[]> | undefined;
    resolver: LoadContracts.LoadedContract;
    host: LoadContracts.LoadedContract;
    agreements: Agreements;
    tokens: { [key: string]: any };
    superTokens: { [key: string]: any };
    cfa: ConstantFlowAgreementV1Helper | undefined;
    ida: InstantDistributionAgreementV1Helper | undefined;
    utils: Utils | undefined;
    _gasMetering: GasMeter | undefined;

    initialize(): Promise<any>;
    isSuperTokenListed(superTokenKey: string): Promise<boolean>;
    loadToken(tokenKey: string): Promise<void>;
    createERC20Wrapper(tokenInfo: any, { superTokenSymbol, superTokenName, from, upgradability }?: string): Promise<any>;
    user({ address, token, options }: {
        address: string;
        token: string;
        options?: any;
    }): User;
    batchCall(calls: any): any;
    _pushTxForGasReport(tx: GasMeter.Record, actionName: string): void;
    generateGasReport(name: string): void;
}

export = Framework;