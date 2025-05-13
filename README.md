# mysqlcve

本项目用于自动化获取、整理和扫描MySQL相关CVE信息。

## 功能
- 自动同步最新MySQL相关CVE数据（基于官方cvelistV5仓库）
- 支持网段MySQL服务版本扫描
- 支持按MySQL版本匹配相关CVE
- 结果以markdown格式输出，便于查阅

## 目录结构
- `mysql_cve.sh`：主脚本，包含数据更新、网段扫描与CVE匹配功能
- `mysqlcve.db`：DuckDB数据库，存储CVE数据
- `scan_result.md`：最近一次CVE匹配结果
- `cvelistV5/`：CVE官方数据子模块（大仓库，首次clone需耐心等待）

## 使用方法

### 1. 克隆本项目（含子模块）
```bash
git clone --recurse-submodules https://github.com/kevinbin/mysqlcve.git
cd mysqlcve
```

### 2. 更新CVE数据
- 全量更新：
  ```bash
  ./mysql_cve.sh update
  ```
- 指定年份更新：
  ```bash
  ./mysql_cve.sh update 2024
  ```

### 3. 扫描网段内MySQL服务版本
```bash
./mysql_cve.sh scan <net_prefix>
# 例如：
./mysql_cve.sh scan 192.168.1
```
会扫描192.168.1.1-254网段，输出发现的MySQL服务及其版本。

### 4. 匹配指定MySQL版本的CVE
```bash
./mysql_cve.sh match <mysql_version>
# 例如：
./mysql_cve.sh match 8.0.32
```
会在本地数据库中查找与该版本相关的CVE，结果以markdown格式输出到 `scan_result.md`。

## 依赖
- [DuckDB](https://duckdb.org/)（需命令行可用）
- bash shell
- git
- nc (netcat)
- strings (binutils)

## 注意事项
- `cvelistV5` 目录为子模块，首次clone需加 `--recurse-submodules`，如需更新子模块：
  ```bash
  git submodule update --init --recursive
  ```
- 数据库和扫描结果文件已纳入版本控制，便于直接查阅和二次开发。
- `scan` 命令仅检测开放3306端口的主机，版本识别依赖MySQL握手包。
- `match` 命令输出的CVE结果为markdown表格，便于直接查阅或导出。

## License
MIT 