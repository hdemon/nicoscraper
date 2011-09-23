# -*- encoding: utf-8 -*-

module Nicos
  VERSION = "0.2.4"

  # nicos.rbが存在する絶対パスを取得
  ROOT = File.expand_path(File.dirname(__FILE__))

  # 追加で読み込みたいファイルがあればここに記載。
  # ADDON = File.join(ROOT, '', '')

  #
  CONFIG_DIR = File.join(ROOT, 'config')
end

# Load Config
Dir.glob(File.join(Nicos::CONFIG_DIR, '*.rb')).each do |file|
  require file
end
