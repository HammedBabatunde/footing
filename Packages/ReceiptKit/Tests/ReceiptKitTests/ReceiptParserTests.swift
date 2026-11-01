import Foundation
import Testing
@testable import ReceiptKit

@Suite("Receipt parsing")
struct ReceiptParserTests {
    let parser = ReceiptParser()

    /// The Tesco receipt used in the Figma designs, as Vision would read it.
    static let tescoExpress = """
    TESCO
    Express
    Whitechapel Road, London E1
    VAT NO: GB 220 4302 31
    SEMI SKIMMED MILK 2L      £1.65 A
    HOVIS SEED SENSATIONS     £1.85 A
    PARACETAMOL 16 CAPLETS    £0.75 D
    FAIRY WASHING UP LIQUID   £1.50 D
    CHICKEN BREAST FILLETS    £5.25 A
    BASMATI RICE 4KG          £7.49 A
    TOTAL                     £18.49
    VISA CONTACTLESS          £18.49
    VAT 20%                   £0.38
    31/10/26  18:42
    THANK YOU FOR SHOPPING AT TESCO
    """

    @Test func readsTheTescoReceipt() throws {
        let receipt = parser.parse(text: Self.tescoExpress)
        #expect(receipt.merchantName == "Tesco")
        #expect(receipt.items.count == 6)
        #expect(receipt.items.first?.name == "Semi Skimmed Milk 2L")
        #expect(receipt.total == Decimal(string: "18.49")!)
        #expect(receipt.itemsMatchTotal)
        #expect(receipt.paymentMethod == "Contactless")
        #expect(receipt.purchaseDate != nil)
    }

    @Test func readsQuantitiesAndDiscounts() throws {
        let receipt = parser.parse(text: """
        SAINSBURY'S
        BANANAS 3 x 0.20          0.60
        COCA COLA 330ML
        2 x £1.50                 3.00
        NECTAR PRICE SAVING      -0.50
        BALANCE DUE               3.10
        """)
        #expect(receipt.merchantName == "Sainsbury's")
        #expect(receipt.items.count == 3)
        #expect(receipt.items[0].quantity == 3)
        #expect(receipt.items[1].name == "Coca Cola 330ML")
        #expect(receipt.items[1].quantity == 2)
        #expect(receipt.items[2].isDiscount)
        #expect(receipt.total == Decimal(string: "3.10")!)
        #expect(receipt.itemsMatchTotal)
    }

    @Test func groupsSeparateTextBoxesIntoRows() {
        let lines = [
            RecognizedLine(text: "MILK", minX: 0.1, maxX: 0.3, midY: 0.80, height: 0.02),
            RecognizedLine(text: "1.65", minX: 0.8, maxX: 0.9, midY: 0.805, height: 0.02),
            RecognizedLine(text: "TOTAL", minX: 0.1, maxX: 0.3, midY: 0.70, height: 0.02),
            RecognizedLine(text: "1.65", minX: 0.8, maxX: 0.9, midY: 0.70, height: 0.02)
        ]
        #expect(parser.rows(from: lines) == ["MILK  1.65", "TOTAL  1.65"])
    }

    @Test func keepsCloseLinesApartWhenTheyOverlapSideways() {
        // Two items on a slightly tilted photo: close in height, but the names overlap side to side.
        let lines = [
            RecognizedLine(text: "344655 Ibuprofen", minX: 0.05, maxX: 0.45, midY: 0.600, height: 0.02),
            RecognizedLine(text: "1.89", minX: 0.80, maxX: 0.90, midY: 0.598, height: 0.02),
            RecognizedLine(text: "404824 Mars Bar", minX: 0.05, maxX: 0.42, midY: 0.592, height: 0.02),
            RecognizedLine(text: "0.95", minX: 0.80, maxX: 0.90, midY: 0.589, height: 0.02)
        ]
        #expect(parser.rows(from: lines) == ["344655 Ibuprofen  1.89", "404824 Mars Bar  0.95"])
    }

    @Test func readsAnAldiReceipt() throws {
        let text = """
        ALDI
        28/10/26 15:21
        335782 Water Still Spring   1.69 A
        416713 Milk Semi Skim 6PT   2.40 A
        339914 Red Onions           0.35 A
        344655 Ibuprofen            1.89 A
        404824 Mars Bar             0.95 A
        Goods                       7.28
        Total                       7.28
        Contactless                 7.28
        """
        let receipt = parser.parse(text: text)
        #expect(receipt.items.map(\.name) == ["Water Still Spring", "Milk Semi Skim 6PT", "Red Onions", "Ibuprofen", "Mars Bar"])
        #expect(receipt.subtotal == Decimal(string: "7.28")!)
        #expect(receipt.total == Decimal(string: "7.28")!)
        #expect(receipt.itemsMatchTotal)
    }
}

@Suite("Categorising")
struct CategoriserTests {
    @Test func usesMerchantAndKeywordRulesOffline() async {
        let receipt = ReceiptParser().parse(text: ReceiptParserTests.tescoExpress)
        let (result, engine) = await Categoriser().categorise(receipt)
        #expect(engine == "Built-in rules")
        #expect(result.category == .food)
        #expect(result.items.map(\.category) == [.food, .food, .health, .other, .food, .food])
    }

    @Test func yourCorrectionsWin() async {
        let receipt = ParsedReceipt(merchantName: "Tesco", items: [ParsedLineItem(name: "Fairy washing up liquid", lineTotal: 1.5)])
        let categoriser = Categoriser(userRules: [CategoryRule(keyword: "fairy", category: .utilities)])
        let (result, _) = await categoriser.categorise(receipt)
        #expect(result.items[0].category == .utilities)
    }
}
