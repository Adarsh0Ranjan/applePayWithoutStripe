//
//  ContentView.swift
//  ApplePayWithStripe
//
//  Created by Adarsh Ranjan on 24/11/23.
//

import SwiftUI
import PassKit

struct ContentView: View {
    let paymentHandler = PaymentHandler()
    var body: some View {
        
        PaymentButton(action: {
            paymentHandler.startPayment(total: 200) { success in
                print("paid \(200)")
            }
        })
        .padding()
        
        Button {
            paymentHandler.startPayment(total: 200) { success in
                print("paid \(200)")
            }
        } label: {
            Text("pay now with apple")
        }
        .padding()
    }
}

struct PaymentButton: View {
    var action: () -> Void
    var body: some View {
        Representable(action: action)
            .frame(maxWidth: .infinity, maxHeight: 50)
    }
}

extension PaymentButton {
    struct Representable: UIViewRepresentable {
        var action: () -> Void
        
        func makeCoordinator() -> Coordinator {
            Coordinator(action: action)
        }
        
        func makeUIView(context: Context) -> some UIView {
            context.coordinator.button
        }
        
        func updateUIView(_ uiView: UIViewType, context: Context) {
            context.coordinator.action = action
        }
        
    }
    
    class Coordinator: NSObject {
        var action: () -> Void
        var button = PKPaymentButton(paymentButtonType: .continue, paymentButtonStyle: .automatic)
        
        init(action: @escaping () -> Void) {
            self.action = action
            super.init()
            
            button.addTarget(self, action: #selector(callback(_:)), for: .touchUpInside)
        }
        
        @objc
        func callback(_ sender: Any) {
            action()
        }
    }
}

typealias PaymentCompletionHandler = (Bool) -> Void

class PaymentHandler: NSObject {
    
    var paymentController: PKPaymentAuthorizationController?
    var paymentSummaryItems = [PKPaymentSummaryItem]()
    var paymentStatus = PKPaymentAuthorizationStatus.failure
    var completionHandler: PaymentCompletionHandler?
    
    static let supportedNetworks: [PKPaymentNetwork] = [
        .visa,
        .masterCard,
    ]
    
    // Define the shipping methods
    func shippingMethodCalculator() -> [PKShippingMethod] {
        
        let today = Date()
        let calendar = Calendar.current
        
        let shippingStart = calendar.date(byAdding: .day, value: 5, to: today)
        let shippingEnd = calendar.date(byAdding: .day, value: 10, to: today)
        
        if let shippingEnd = shippingEnd, let shippingStart = shippingStart {
            let startComponents = calendar.dateComponents([.calendar, .year, .month, .day], from: shippingStart)
            let endComponents = calendar.dateComponents([.calendar, .year, .month, .day], from: shippingEnd)
            
            let shippingDelivery = PKShippingMethod(label: "Delivery", amount: NSDecimalNumber(string: "0.00"))
            shippingDelivery.dateComponentsRange = PKDateComponentsRange(start: startComponents, end: endComponents)
            shippingDelivery.detail = "Sweaters sent to your address"
            shippingDelivery.identifier = "DELIVERY"
            
            return [shippingDelivery]
        }
        return []
    }
    
    func startPayment(total: Int, completion: @escaping PaymentCompletionHandler) {
        completionHandler = completion
        
        // Reset the paymentSummaryItems array before adding to it
        paymentSummaryItems = []
        // Add a PKPaymentSummaryItem for the total to the paymentSummaryItems array
        let rent = PKPaymentSummaryItem(label: "Rent", amount: NSDecimalNumber(string: "9.99"), type: .final)
        let deposit = PKPaymentSummaryItem(label: "Deposit", amount: NSDecimalNumber(string: "1.00"), type: .final)
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(string: "10.99"), type: .final)
        paymentSummaryItems = [rent, deposit, total]

        // Create a payment request and add all data to it
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = paymentSummaryItems // Set paymentSummaryItems to the paymentRequest
        paymentRequest.merchantIdentifier = "merchant.applePayWithoutStripe.demo"
        paymentRequest.merchantCapabilities = .threeDSecure // A security protocol used to authenticate users
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        paymentRequest.supportedNetworks = PaymentHandler.supportedNetworks // Types of cards supported
        paymentRequest.shippingType = .storePickup
        
        // we can do when we want to add delivery pick up
//        paymentRequest.shippingMethods = shippingMethodCalculator()
//        paymentRequest.requiredShippingContactFields = [.name, .postalAddress]
        
        // Display the payment request in a sheet presentation
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        paymentController?.present(completion: { (presented: Bool) in
            if presented {
                debugPrint("Presented payment controller")
            } else {
                debugPrint("Failed to present payment controller")
            }
        })
    }
}

// Set up PKPaymentAuthorizationControllerDelegate conformance
extension PaymentHandler: PKPaymentAuthorizationControllerDelegate {

    // Handle success and errors related to the payment
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

        let errors = [Error]()
        let status = PKPaymentAuthorizationStatus.success

        self.paymentStatus = status
        completion(PKPaymentAuthorizationResult(status: status, errors: errors))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // The payment sheet doesn't automatically dismiss once it has finished, so dismiss the payment sheet
            DispatchQueue.main.async {
                if self.paymentStatus == .success {
                    if let completionHandler = self.completionHandler {
                        completionHandler(true)
                    }
                } else {
                    if let completionHandler = self.completionHandler {
                        completionHandler(false)
                    }
                }
            }
        }
    }
}
