# shared ディレクトリ

外部ファイル・リポジトリを家来（家老・足軽）と共有するための場所。

## 用途
- 外部リポジトリのフォルダをここにコピーまたはシンボリックリンクで配置
- 殿が家来に見せたい資料・ファイルの置き場
- Git追跡対象外（README.mdのみ追跡）

## 使い方

```bash
# 例1: 外部リポジトリをシンボリックリンクで配置
ln -s /path/to/external/repo shared/repo_name

# 例2: フォルダをコピーして配置
cp -r /path/to/external/repo shared/repo_name
```

## 家来への指示での参照方法

```yaml
# queue/shogun_to_karo.yaml での指示例
command: "shared/repo_name を解析し、構成を報告せよ"
```

## 注意事項
- このディレクトリ配下は `.gitignore` でGit追跡対象外
- 機密情報を含むファイルも安全に配置可能
- 容量の大きいファイルも問題なし
