import Foundation
struct StationSource: Identifiable { let id: String; let title: String; let url: String; let perspective: String; var kind: SourceKind = .feed }
struct ResearchTopic: Identifiable { let id: String; let title: String }
enum StationCatalog {
 static let aiSources: [StationSource] = [
 .init(id:"openai",title:"OpenAI",url:"https://openai.com/news/rss.xml",perspective:"Company"),
 .init(id:"anthropic",title:"Anthropic / Claude",url:"https://www.anthropic.com/news",perspective:"Company"),
 .init(id:"deepmind",title:"Google DeepMind",url:"https://deepmind.google/blog/rss.xml",perspective:"Company"),
 .init(id:"huggingface",title:"Hugging Face",url:"https://huggingface.co/blog/feed.xml",perspective:"Professional community"),
 .init(id:"mit-ai",title:"MIT AI",url:"https://news.mit.edu/rss/topic/artificial-intelligence2",perspective:"Academic"),
 .init(id:"bair",title:"BAIR",url:"https://bair.berkeley.edu/blog/feed.xml",perspective:"Academic"),
 .init(id:"microsoft",title:"Microsoft Research",url:"https://www.microsoft.com/en-us/research/feed/",perspective:"Company"),
 .init(id:"nvidia",title:"NVIDIA",url:"https://blogs.nvidia.com/feed/",perspective:"Company"),
 .init(id:"ars",title:"Ars Technica",url:"https://feeds.arstechnica.com/arstechnica/technology-lab",perspective:"Reporting")]
 static let researchTopics: [ResearchTopic] = [("cs.AI","AI"),("cs.LG","Machine learning"),("physics","Physics"),("quant-ph","Quantum physics"),("astro-ph","Astronomy"),("gr-qc","Relativity"),("hep-ph","Particle physics"),("cond-mat","Condensed matter"),("math","Mathematics"),("q-bio.NC","Neuroscience"),("cs.RO","Robotics")].map { .init(id:$0.0,title:$0.1) }
 static var presets: [RadioChannel] { RadioChannel.allCases.filter { $0 != .custom } }
 static func sources(for channel: RadioChannel) -> [StationSource] {
 switch channel {
 case .finance: return [.init(id:"cnbc-finance",title:"CNBC Finance",url:"https://www.cnbc.com/id/10000664/device/rss/rss.html",perspective:"Reporting"),.init(id:"federal-reserve",title:"Federal Reserve",url:"https://www.federalreserve.gov/feeds/press_monetary.xml",perspective:"Official releases")]
 case .stocks: return [.init(id:"cnbc-earnings",title:"CNBC Earnings",url:"https://www.cnbc.com/id/15839135/device/rss/rss.html",perspective:"Reporting"),.init(id:"cnbc-markets",title:"CNBC Market Insider",url:"https://www.cnbc.com/id/20409666/device/rss/rss.html",perspective:"Reporting")]
 case .resets: return [.init(id:"codex-resets",title:"Codex Resets · @thsottiaux on X",url:"https://codex-resets.com/api/v1/resets",perspective:"Community tracker")]
 case .games: return [.init(id:"gamedeveloper",title:"Game Developer",url:"https://www.gamedeveloper.com/rss.xml",perspective:"Professional community"),.init(id:"eurogamer",title:"Eurogamer",url:"https://www.eurogamer.net/feed",perspective:"Reporting")]
 case .education: return [.init(id:"mit-education",title:"MIT Education",url:"https://news.mit.edu/rss/topic/education",perspective:"Academic"),.init(id:"edsurge",title:"EdSurge",url:"https://www.edsurge.com/articles_rss",perspective:"Reporting")]
 case .psychology: return [.init(id:"aps",title:"Association for Psychological Science",url:"https://www.psychologicalscience.org/feed",perspective:"Professional community")]
 case .philosophy: return [.init(id:"dailynous",title:"Daily Nous",url:"https://dailynous.com/feed/",perspective:"Professional community")]
 case .science: return [.init(id:"sciencedaily",title:"ScienceDaily",url:"https://www.sciencedaily.com/rss/top/science.xml",perspective:"Reporting")]
 case .technology: return [aiSources.last!]
 default: return []
 }
 }
}
