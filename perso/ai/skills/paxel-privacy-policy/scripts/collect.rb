require "fileutils"
require "json"
require "nokogiri"
require "open3"
require "optparse"
require "time"

ALLOWED_TAGS = %w[h1 h2 h3 h4 p ul ol li table thead tbody tr th td strong em a code pre br].freeze
YC_SOURCE_PATHS = {
  "builder-profile-section.tsx" => "apply/app/javascript/src/components/paxel/BuilderProfileSection.tsx",
  "paxel-promo-card.tsx" => "apply/app/javascript/src/components/paxel/PaxelPromoCard.tsx",
  "paxel-connected-card.tsx" => "apply/app/javascript/src/components/paxel/PaxelConnectedCard.tsx",
  "paxel-link-account-card.tsx" => "apply/app/javascript/src/components/paxel/PaxelLinkAccountCard.tsx",
  "use-paxel-state.ts" => "apply/app/javascript/src/components/hooks/usePaxelState.ts",
  "applicant-reminder-trigger.rb" => "ycinternal/app/models/applicant.rb",
  "apps-mailer.rb" => "ycinternal/app/mailers/apps_mailer.rb",
  "paxel-report-reminder.html.slim" => "ycinternal/app/views/mailers/apps_mailer/paxel_report_reminder.html.slim",
  "apply-support-faq.rb" => "ycinternal/db/migrate/20260725024227_add_paxel_faq_to_apply_front_agent.rb"
}.freeze

options = {
  output: Rails.root.join(".context/paxel-privacy-policy").to_s,
  paxel_ref: "origin/main",
  yc_ref: "origin/master"
}

OptionParser.new do |parser|
  parser.on("--output PATH") { options[:output] = _1 }
  parser.on("--paxel-ref REF") { options[:paxel_ref] = _1 }
  parser.on("--proposed-ref REF") { options[:proposed_ref] = _1 }
  parser.on("--yc-code-root PATH") { options[:yc_code_root] = _1 }
  parser.on("--yc-ref REF") { options[:yc_ref] = _1 }
end.parse!(ARGV)

def git(*args, chdir:)
  output, status = Open3.capture2e("git", *args, chdir: chdir)
  raise "git #{args.join(' ')} failed: #{output}" unless status.success?

  output
end

def portable_html(node)
  fragment = Nokogiri::HTML.fragment(node.inner_html)
  fragment.css("style, script").remove

  fragment.xpath(".//*").reverse_each do |element|
    unless ALLOWED_TAGS.include?(element.name)
      element.replace(element.children)
      next
    end

    href = element["href"] if element.name == "a"
    element.attribute_nodes.each(&:remove)
    next unless href

    href = "https://paxel.ycombinator.com#{href}" if href.start_with?("/")
    element["href"] = href
  end

  fragment.to_html
end

def section(html, selector)
  node = Nokogiri::HTML(html).at_css(selector)
  raise "Missing selector #{selector}" unless node

  portable_html(node)
end

def wrap(title, note, body)
  "<h1>#{title}</h1>\n<p>#{note}</p>\n#{body}"
end

def render_inline(template)
  ApplicationController.render(inline: template, layout: false)
end

def faq_template(source)
  match = source.match(/<% hv3_faqs = \[(.*?)\]\s*%>/m)
  raise "Could not find hv3_faqs in home_v3/show.html.erb" unless match

  <<~ERB
    <% hv3_faqs = [#{match[1]}] %>
    <% hv3_faqs.each do |question, answer, _open| %>
      <div class="hv3-faq-item">
        <p class="hv3-faq-q"><%= question %></p>
        <p class="hv3-faq-a"><%= sanitize(answer, tags: %w[a code strong img], attributes: %w[href src alt class]) %></p>
      </div>
    <% end %>
  ERB
end

output = File.expand_path(options[:output])
FileUtils.mkdir_p(output)

privacy_template = git("show", "#{options[:paxel_ref]}:app/views/home/_privacy_body.html.erb", chdir: Rails.root.to_s)
privacy = section(render_inline(privacy_template), "[data-legal-document='paxel-privacy']")
privacy = privacy.sub(/\A\s*<h1[^>]*>.*?<\/h1>/m, "")
File.write(
  File.join(output, "privacy.html"),
  wrap(
    "Paxel Privacy Policy",
    '<strong>Binding legal policy.</strong> Source: <a href="https://paxel.ycombinator.com/privacy">paxel.ycombinator.com/privacy</a>.',
    privacy
  )
)

data_handling_template = git("show", "#{options[:paxel_ref]}:app/views/home/data_handling.html.erb", chdir: Rails.root.to_s)
data_handling = section(render_inline(data_handling_template), ".w-full.max-w-2xl.mx-auto")
data_handling = data_handling.sub(/\A\s*<h1[^>]*>.*?<\/h1>/m, "")
File.write(
  File.join(output, "data-handling-current.html"),
  wrap(
    "Paxel Data Handling — Current",
    '<strong>Current technical companion.</strong> Source: <a href="https://paxel.ycombinator.com/data-handling">paxel.ycombinator.com/data-handling</a>.',
    data_handling
  )
)

home_template = git("show", "#{options[:paxel_ref]}:app/views/home_v3/show.html.erb", chdir: Rails.root.to_s)
faq = Nokogiri::HTML(render_inline(faq_template(home_template))).css(".hv3-faq-item").map do |item|
  question = item.at_css(".hv3-faq-q")&.text&.strip
  answer = item.at_css(".hv3-faq-a")
  raise "Malformed website FAQ item" unless question && answer

  "<h2>#{question}</h2><p>#{portable_html(answer)}</p>"
end.join("\n")
File.write(
  File.join(output, "website-faq.html"),
  wrap(
    "Paxel Website FAQ",
    'Source: <a href="https://paxel.ycombinator.com/#faq">paxel.ycombinator.com/#faq</a>.',
    faq
  )
)

if options[:proposed_ref]
  template = git("show", "#{options[:proposed_ref]}:app/views/home/data_handling.html.erb", chdir: Rails.root.to_s)
  proposed = section(render_inline(template), ".w-full.max-w-2xl.mx-auto")
  proposed = proposed.sub(/\A\s*<h1[^>]*>.*?<\/h1>/m, "")
  File.write(
    File.join(output, "data-handling-proposed.html"),
    wrap(
      "Paxel Data Handling — Proposed",
      "<strong>Unmerged proposal.</strong> Source ref: <code>#{options[:proposed_ref]}</code>. Confirm PR status and Legal approval before publication.",
      proposed
    )
  )
end

yc_sources = {}
if options[:yc_code_root]
  source_dir = File.join(output, "yc-code-sources")
  FileUtils.mkdir_p(source_dir)
  YC_SOURCE_PATHS.each do |name, path|
    File.write(File.join(source_dir, name), git("show", "#{options[:yc_ref]}:#{path}", chdir: options[:yc_code_root]))
    yc_sources[name] = path
  end
end

manifest = {
  generated_at: Time.now.utc.iso8601,
  paxel_root: Rails.root.to_s,
  paxel_head: git("rev-parse", "HEAD", chdir: Rails.root.to_s).strip,
  paxel_ref: options[:paxel_ref],
  paxel_sha: git("rev-parse", options[:paxel_ref], chdir: Rails.root.to_s).strip,
  proposed_ref: options[:proposed_ref],
  proposed_sha: options[:proposed_ref] && git("rev-parse", options[:proposed_ref], chdir: Rails.root.to_s).strip,
  yc_code_root: options[:yc_code_root],
  yc_ref: options[:yc_code_root] && options[:yc_ref],
  yc_sha: options[:yc_code_root] && git("rev-parse", options[:yc_ref], chdir: options[:yc_code_root]).strip,
  yc_sources: yc_sources
}
File.write(File.join(output, "source-manifest.json"), JSON.pretty_generate(manifest))

puts "Wrote Paxel privacy packet to #{output}"
