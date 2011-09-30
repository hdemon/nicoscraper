module Nicos
  module Connector
    class Config
      @@waitConfigDefault =
      @@waitConfig = {
        :seqAccLimit => 10,  # 連続してリクエストする回数
        :afterSeq    => 10,  # 連続リクエスト後のウェイト（以下全て単位は秒）
        :each        => 1,   # 連続リクエスト時の、1リクエスト毎のウェイト

        :increment   => 1,   # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量

        :deniedSeqReq=> {    # 連続アクセス拒絶時
          :retryLimit  => 3,   # 再試行回数の上限
          :wait        => 120  # 再試行までのウェイト
        },
        
        :serverIsBusy=> {    # サーバ混雑時
          :retryLimit  => 3,
          :wait        => 120
        },
        
        :serviceUnavailable => { # 503時
          :retryLimit  => 3,
          :wait        => 120
        },
        
        :timedOut => {       # タイムアウト時
          :retryLimit  => 3,
          :wait        => 10
        }
      }

      def Config.setWaitDefault(waitConfig)
        @@waitConfigDefault = mixinND(
          @@waitConfigDefault,
          waitConfig
        )      
      end

      def Config.setWait(waitConfig)
        case waitConfig
        when :default
          @@waitConfig = @@waitConfigDefault
        when nil
        else
          @@waitConfig = mixinND(
            @@waitConfig,
            waitConfig
          )
        end
      end
    end

    module SetWait
      def setWait(waitConfig)
        @waitConfig = mixinND(
          @waitConfig,
          waitConfig
        ) if waitConfig != nil
      end
    end
  end
end
