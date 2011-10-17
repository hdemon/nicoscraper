# -*- encoding: utf-8 -*-
module Nicos
  VERSION = "0.2.13"
  REPOSITORY =
    "http://github.com/hdemon/nicoscraper/"
  AUTHOR = "Masami Yonehara"
    
  # nicos.rbが存在する絶対パスを取得
  ROOT = File.expand_path(File.dirname(__FILE__))

  # 追加で読み込みたいファイルがあればここに記載。
  # ADDON = File.join(ROOT, '', '')

  #
  CONFIG_DIR = File.join(ROOT, 'config')
  CLASSES = File.join(ROOT, 'classes')
end

# puts Nicos::ROOT
# puts Nicos::CONFIG_DIR

# Load files.
[
  Nicos::CONFIG_DIR, 
  Nicos::CLASSES
].each do |path|
  Dir.glob(File.join(path, '*.rb')).each do |file|
    require file
    # puts file
  end
end
