#!/bin/bash

# usage:
#   ./mysql_cve.sh update [YEAR]
#   ./mysql_cve.sh scan <mysql_version>

ACTION="$1"
TARGET="$2"

CVE_DIR="cvelistV5"

if [ "$ACTION" = "update" ]; then
  # 先拉取最新CVE数据
  if [ -d "$CVE_DIR/.git" ]; then
    echo "正在同步最新CVE数据..."
    git -C "$CVE_DIR" pull --ff-only https://github.com/CVEProject/cvelistV5.git main
  else
    echo "未检测到 $CVE_DIR 是git仓库，请先用git clone下载：https://github.com/CVEProject/cvelistV5.git"
    exit 1
  fi

  if [ -n "$TARGET" ]; then
    # 指定了年份，只更新该年
    if [[ ! "$TARGET" =~ ^20[0-9][0-9]$ ]]; then
      echo "年份格式错误，请输入如 2025 这样的年份"
      exit 1
    fi
    JSON_PATH="read_json('cvelistV5/cves/$TARGET/*/*.json', union_by_name = true, ignore_errors = true)"
  else
    # 未指定年份，全量更新
    JSON_PATH="read_json('cvelistV5/cves/20*/*/*.json', union_by_name = true, ignore_errors = true)"
  fi

  duckdb mysqlcve.db <<EOF
CREATE TABLE IF NOT EXISTS mysqlcve (
    cveid VARCHAR PRIMARY KEY,
    product VARCHAR,
    versions VARCHAR,
    description VARCHAR,
    severity VARCHAR,
    published_date TIMESTAMP,
    cve_url VARCHAR
);

INSERT INTO mysqlcve
SELECT
    cveMetadata.cveId as cveid,
    any_value(containers.cna.affected[1].product) as product,
    string_agg(
        coalesce(v.lessThanOrEqual,
        regexp_replace(v.version, ' and prior|and earlier', '')), ', '
    ) as versions,
    any_value(containers.cna.descriptions[1].value) as description,
    any_value(coalesce(json_value(containers,'$.cna.metrics[1].cvssV3_0.baseSeverity'), containers.cna.metrics[1].cvssV3_1.baseSeverity)) as severity,
    any_value(cveMetadata.datePublished) as published_date,
    any_value(concat('https://nvd.nist.gov/vuln/detail/', cveMetadata.cveId)) as cve_url
FROM $JSON_PATH
CROSS JOIN UNNEST(containers.cna.affected[1].versions) AS t(v)
WHERE LOWER(containers.cna.affected[1].product) LIKE '%mysql server%'
GROUP BY cveid
ON CONFLICT(cveid) DO UPDATE SET
    product=excluded.product,
    versions=excluded.versions,
    description=excluded.description,
    severity=excluded.severity,
    published_date=excluded.published_date,
    cve_url=excluded.cve_url;
EOF

elif [ "$ACTION" = "scan" ] && [ -n "$TARGET" ]; then
  duckdb mysqlcve.db <<EOF
.output scan_result.md
.mode markdown
WITH cve_with_versions AS (
    SELECT
      cveid, product, versions, description, severity, published_date, cve_url,
      string_split(versions, ', ') AS version_arr
    FROM mysqlcve
)
SELECT cveid, product, versions, severity, published_date, cve_url
FROM cve_with_versions
CROSS JOIN UNNEST(version_arr) AS t(v)
WHERE
  CAST(split_part(v, '.', 1) AS INT) = CAST(split_part('$TARGET', '.', 1) AS INT)
  AND CAST(split_part(v, '.', 2) AS INT) = CAST(split_part('$TARGET', '.', 2) AS INT)
  AND CAST(split_part(v, '.', 3) AS INT) >= CAST(split_part('$TARGET', '.', 3) AS INT)
ORDER BY published_date DESC;
EOF
  echo "扫描结果已输出到 scan_result.md"
else
  echo "Usage:"
  echo "  $0 update [YEAR]"
  echo "  $0 scan <mysql_version>"
  exit 1
fi