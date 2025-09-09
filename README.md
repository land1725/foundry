# <h1 align="center"> Foundry 智能合约项目 </h1>

**基于 Foundry 快速开始智能合约开发的模板项目**

![Github Actions](https://github.com/foundry-rs/forge-template/workflows/CI/badge.svg)

## 快速开始

### 环境要求
- [Foundry](https://getfoundry.sh) - Solidity 开发工具链

### 安装和运行

1. 克隆项目并安装依赖：
```sh
git clone https://github.com/land1725/foundry.git
cd foundry
git submodule update --init --recursive
```

2. 编译合约：
```sh
forge build
```

3. 运行测试：
```sh
forge test
```

4. 运行详细测试（显示日志）：
```sh
forge test -vvv
```

## 项目结构

```
├── src/           # 智能合约源码
├── test/          # 测试文件
├── lib/           # 依赖库（如 forge-std）
├── foundry.toml   # Foundry 配置文件
└── README.md      # 项目说明
```

## 合约功能

本项目包含一个简单的 `Contract` 合约，提供以下功能：

- `add(uint256 a, uint256 b)` - 加法运算
- `sub(uint256 a, uint256 b)` - 减法运算

## 测试说明

测试文件位于 `test/Contract.t.sol`，包含：

- `testAdd()` - 测试加法功能
- `testSub()` - 测试减法功能
- 详细的控制台日志输出，便于调试

### 编写测试

所有测试都需要继承 `forge-std/Test.sol`。Forge 提供了完整的测试环境，包括：

- [作弊码环境](https://book.getfoundry.sh/cheatcodes/) (`vm`)
- [断言库](https://book.getfoundry.sh/reference/ds-test.html)
- [控制台日志](https://github.com/brockelmore/forge-std/blob/master/src/console.sol) (`console.log`)

```solidity
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

contract MyTest is Test {
    function testExample() public {
        console.log("开始测试...");
        vm.roll(100);  // 设置区块号
        assertTrue(true);
        console.log("测试完成！");
    }
}
```

## 开发工具

本项目使用 [Foundry](https://getfoundry.sh) 作为开发框架。详细文档请参考 [Foundry Book](https://book.getfoundry.sh/getting-started/installation.html)。

### 常用命令

- `forge build` - 编译合约
- `forge test` - 运行测试
- `forge test -vvv` - 运行测试并显示详细日志
- `forge fmt` - 格式化代码
- `forge install <dependency>` - 安装依赖

## 贡献

欢迎提交 Issue 和 Pull Request！
