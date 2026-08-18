# frozen_string_literal: true

require "date"
require "time"

# EtherNotes — 目录树 → 列/子列/系列 分组生成器
#
# 约定：docs/_posts/<列>/<子列>/[<系列>/]<日期>-<slug>.md
#   - 三段路径（列/子列/系列/文件）→ 属于一个「系列」中的文章
#   - 两段路径（列/子列/文件）      → 子列下的直接文章
#   - 一段路径（列/文件）           → 列下的直接文章（不常见，兜底）
#
# 产出（写入 site.data，供 Liquid 直接读取）：
#   site.data["grouped_posts"] — 按 _data/columns.yml 顺序组织的分类树：
#     [ { "key" =>, "name" =>,
#         "subcolumns" => [ { "key" =>, "name" =>,
#             "series" => [ { "key" =>, "name" =>, "posts" => [Doc...] } ],
#             "direct_posts" => [Doc...] } ],
#         "direct_posts" => [Doc...] } ]
#   site.data["post_series"]  — url => { "name" =>, "col_key" =>, "col_name" =>,
#                                          "sub_key" =>, "sub_name" =>, "posts" => [Doc...] }
#                               仅在「系列」中的文章存在此索引

module EtherNotes
  class GroupedPosts < Jekyll::Generator
    safe true
    priority :normal

    INF = Float::INFINITY

    def generate(site)
      posts = site.posts.docs

      # 1. 读列/子列配置（显示名与顺序）
      cols_meta = (site.data["columns"] || {})["columns"] || []

      # 2. 收集原始分组结构（保持配置 + 目录出现顺序）
      # relative_path 形如 "_posts/<列>/<子列>/[<系列>/]<文件>"
      # 去掉首段 "_posts" 与末段文件名，剩下的目录段即：列/子列/[系列]
      columns = {} # key => {name:, subs: {key => {name:, series: {key => [docs]}, direct: []}}, direct: []}
      posts.each do |doc|
        segs = doc.relative_path.split("/")
        next if segs.size < 3 # 至少 "_posts/<列>/<文件>"

        dirs = segs[1..-2] # ["<列>", "<子列>", ("<系列>")?]
        col = dirs[0]
        sub = dirs[1]
        series = dirs[2] # 第三层目录（若有）即系列；更深处（第四层及以后）归入该系列

        node = (columns[col] ||= { name: col, subs: {}, direct: [] })

        if sub.nil?
          # 列下的直接文章：_posts/<列>/<文件>.md
          node[:direct] << doc
        elsif series.nil?
          # 子列下的直接文章：_posts/<列>/<子列>/<文件>.md
          subnode = (node[:subs][sub] ||= { name: sub, series: {}, direct: [] })
          subnode[:direct] << doc
        else
          # 系列文章：_posts/<列>/<子列>/<系列>/<文件>.md（可能更深）
          subnode = (node[:subs][sub] ||= { name: sub, series: {}, direct: [] })
          (subnode[:series][series] ||= []).push(doc)
        end
      end

      # 3. 应用配置中的显示名与顺序，未配置的列/子列按目录名显示并追加
      ordered_cols = cols_meta.map { |c| c["key"] }
      all_col_keys = ordered_cols + (columns.keys - ordered_cols)

      grouped = []
      post_series = {}

      all_col_keys.each do |ckey|
        node = columns[ckey]
        next if node.nil?

        col_meta = cols_meta.find { |c| c["key"] == ckey } || {}
        col_name = col_meta["name"] || ckey

        sub_meta_order = (col_meta["subcolumns"] || []).map { |s| s["key"] }
        all_sub_keys = sub_meta_order + (node[:subs].keys - sub_meta_order)

        subcolumns = []
        all_sub_keys.each do |skey|
          subnode = node[:subs][skey]
          next if subnode.nil?

          sub_meta = (col_meta["subcolumns"] || []).find { |s| s["key"] == skey } || {}
          sub_name = sub_meta["name"] || humanize(skey)

          series = []
          subnode[:series].each do |ser_key, ser_posts|
            sorted = sort_series(ser_posts)
            series << {
              "key"   => ser_key,
              "name"  => humanize(ser_key),
              "posts" => sorted,
            }
            sorted.each do |d|
              post_series[d.url] = {
                "name"     => humanize(ser_key),
                "col_key"  => ckey,
                "col_name" => col_name,
                "sub_key"  => skey,
                "sub_name" => sub_name,
                "posts"    => sorted,
              }
            end
          end

          subcolumns << {
            "key"          => skey,
            "name"         => sub_name,
            "series"       => series,
            "direct_posts" => node[:subs][skey][:direct].sort_by { |d| -date_num(d) },
          }
        end

        grouped << {
          "key"          => ckey,
          "name"         => col_name,
          "subcolumns"   => subcolumns,
          "direct_posts" => node[:direct].sort_by { |d| -date_num(d) },
        }
      end

      site.data["grouped_posts"] = grouped
      site.data["post_series"] = post_series
    end

    private

    # 系列内按 frontmatter `order` 排序（缺省排最后，再按日期稳定）
    def sort_series(docs)
      docs.sort_by { |d| [d.data["order"] || INF, -date_num(d)] }
    end

    # 日期转数值用于排序（date 可能是 Time/Date/字符串）
    def date_num(doc)
      d = doc.data["date"] || doc.date
      case d
      when Time
        d.to_i
      when Date
        d.to_time.to_i
      else
        begin
          Time.parse(d.to_s).to_i
        rescue StandardError
          0
        end
      end
    end

    # 目录名 → 人类可读（下划线转空格，保留连字符）
    def humanize(s)
      s.to_s.tr("_", " ")
    end
  end
end
