import SwiftUI

struct StockQuoteContent: View {
    @ObservedObject var model: RadioModel
    let quote: StockQuote
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(quote.symbol).font(.system(size: 16, weight: .semibold, design: .monospaced))
                if quote.name != quote.symbol { Text(quote.name).font(.system(size: 10)).lineLimit(1) }
            }
            if let price = quote.price {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(price, format: .currency(code: "USD").locale(Locale(identifier: "en_US")))
                        .font(.system(size: 30, weight: .medium, design: .serif)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if let change = quote.changePercent {
                        Text(String(format: "%+.2f%%", change))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                Text(model.t("Regular session · may be delayed")).font(.system(size: 9)).opacity(0.7)
                if let date = quote.asOf {
                    HStack(spacing: 4) {
                        Text(model.t(quote.isCached || model.failures[.stocks] != nil ? "Cached quote" : "As of"))
                        Text(date, format: .dateTime.month(.abbreviated).day().hour().minute().locale(model.language.locale))
                    }.font(.system(size: 10)).lineLimit(1)
                }
            } else {
                Text(model.t("Quote unavailable")).font(.system(size: 19, weight: .medium, design: .serif))
                Text(model.t("Check the symbol or refresh again later."))
                    .font(.system(size: 11)).lineLimit(2)
            }
            Button { model.openSource() } label: {
                HStack(spacing: 4) { Text("Yahoo Finance"); Image(systemName: "arrow.up.right").font(.system(size: 8)) }
            }.buttonStyle(.plain).font(.system(size: 10, weight: .medium)).padding(.top, 3)
        }.padding(.top, 10)
    }
}
