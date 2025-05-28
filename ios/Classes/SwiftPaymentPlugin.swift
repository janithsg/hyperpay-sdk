import Flutter
import UIKit
import SafariServices

public class SwiftPaymentPlugin: NSObject,FlutterPlugin ,SFSafariViewControllerDelegate, OPPCheckoutProviderDelegate   {
    var type:String = "";
    var mode:String = "";
    var checkoutid:String = "";
    var brand:String = "";
    var brandsReadyUi:[String] = [];
    var STCPAY:String = "";
    var number:String = "";
    var holder:String = "";
    var year:String = "";
    var month:String = "";
    var cvv:String = "";
    var pMadaVExp:String = "";
    var prMadaMExp:String = "";
    var brands:String = "";
    var shopperResultURL:String = "";
    var tokenID:String = "";
    var payTypeSotredCard:String = "";
    var applePaybundel:String = "";
    var countryCode:String = "";
    var currencyCode:String = "";
    var setStorePaymentDetailsMode:String = "";
    var lang:String = "";
    var amount:Double = 1;
    var themColorHex:String = "";
    var companyName:String = "";
    var safariVC: SFSafariViewController?
    var transaction: OPPTransaction?
    var provider = OPPPaymentProvider(mode: OPPProviderMode.test)
    var checkoutProvider: OPPCheckoutProvider?
    var Presult:FlutterResult?
    var window: UIWindow?

    // MARK: - Error Logging Utilities
    private func logError(_ message: String, error: Error? = nil, function: String = #function) {
        let errorMessage = "HyperPay Error in \(function): \(message)"
        if let error = error {
            print("\(errorMessage) - \(error.localizedDescription)")
            if let oppError = error as? NSError {
                print("Error Code: \(oppError.code)")
                print("Error Domain: \(oppError.domain)")
                print("Error UserInfo: \(oppError.userInfo)")
            }
        } else {
            print(errorMessage)
        }
    }
    
    private func createDetailedError(code: String, message: String, details: String? = nil) -> FlutterError {
        logError("Flutter Error - Code: \(code), Message: \(message), Details: \(details ?? "N/A")")
        return FlutterError(code: code, message: message, details: details)
    }
    
    private func handleTransactionError(transaction: OPPTransaction?, error: Error?, result: @escaping FlutterResult, context: String) {
        var errorMessage = "Transaction failed in \(context)"
        var errorCode = "TRANSACTION_ERROR"
        var errorDetails: String? = nil
        
        if let error = error {
            let nsError = error as NSError
            errorMessage = "HyperPay Error: \(error.localizedDescription)"
            errorCode = "HYPERPAY_ERROR_\(nsError.code)"
            errorDetails = "Domain: \(nsError.domain), Code: \(nsError.code), UserInfo: \(nsError.userInfo)"
            
            // Log specific HyperPay error codes
            logError("HyperPay SDK Error in \(context)", error: error)
            
            // Handle specific error codes
            switch nsError.code {
            case 100: // OPPErrorCodeTransactionProcessingFailureGeneric
                errorMessage = "Transaction processing failed"
            case 200: // OPPErrorCodeConnectionFailure
                errorMessage = "Network connection failed"
            case 300: // OPPErrorCodeInvalidCheckoutId
                errorMessage = "Invalid checkout ID"
            case 400: // OPPErrorCodeInvalidPaymentBrand
                errorMessage = "Invalid payment brand"
            default:
                break
            }
        }
        
        if let transaction = transaction {
            errorDetails = (errorDetails ?? "") + ", Transaction ID: \(transaction.paymentParams?.checkoutID ?? "Unknown")"
        }
        
        result(createDetailedError(code: errorCode, message: errorMessage, details: errorDetails))
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let flutterChannel:String = "Hyperpay.demo.fultter/channel";
        let channel = FlutterMethodChannel(name: flutterChannel, binaryMessenger: registrar.messenger())
        let instance = SwiftPaymentPlugin()
        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.Presult = result
        
        logError("Method called: \(call.method)")

        if call.method == "gethyperpayresponse"{
            guard let args = call.arguments as? Dictionary<String,Any> else {
                result(createDetailedError(code: "INVALID_ARGUMENTS", message: "Arguments are not in expected format", details: "Expected Dictionary<String,Any>"))
                return
            }
            
            guard let type = args["type"] as? String,
                  let mode = args["mode"] as? String,
                  let checkoutid = args["checkoutid"] as? String,
                  let shopperResultURL = args["ShopperResultUrl"] as? String,
                  let lang = args["lang"] as? String else {
                result(createDetailedError(code: "MISSING_REQUIRED_ARGS", message: "Missing required arguments", details: "Required: type, mode, checkoutid, ShopperResultUrl, lang"))
                return
            }
            
            self.type = type
            self.mode = mode
            self.checkoutid = checkoutid
            self.shopperResultURL = shopperResultURL
            self.lang = lang
            
            logError("Processing payment with type: \(type), mode: \(mode), checkoutId: \(checkoutid)")

            if self.type == "ReadyUI" {
                guard let applePaybundel = args["merchantId"] as? String,
                      let countryCode = args["CountryCode"] as? String,
                      let companyName = args["companyName"] as? String,
                      let brandsReadyUi = args["brand"] as? [String],
                      let themColorHex = args["themColorHexIOS"] as? String,
                      let setStorePaymentDetailsMode = args["setStorePaymentDetailsMode"] as? String else {
                    result(createDetailedError(code: "MISSING_READY_UI_ARGS", message: "Missing ReadyUI required arguments", details: "Required: merchantId, CountryCode, companyName, brand, themColorHexIOS, setStorePaymentDetailsMode"))
                    return
                }
                
                self.applePaybundel = applePaybundel
                self.countryCode = countryCode
                self.companyName = companyName
                self.brandsReadyUi = brandsReadyUi
                self.themColorHex = themColorHex
                self.setStorePaymentDetailsMode = setStorePaymentDetailsMode
                
                DispatchQueue.main.async {
                    self.openCheckoutUI(checkoutId: self.checkoutid, result1: result)
                }
            } else if self.type  == "CustomUI"{
                guard let brands = args["brand"] as? String,
                      let number = args["card_number"] as? String,
                      let holder = args["holder_name"] as? String,
                      let year = args["year"] as? String,
                      let month = args["month"] as? String,
                      let cvv = args["cvv"] as? String,
                      let setStorePaymentDetailsMode = args["EnabledTokenization"] as? String else {
                    result(createDetailedError(code: "MISSING_CUSTOM_UI_ARGS", message: "Missing CustomUI required arguments", details: "Required: brand, card_number, holder_name, year, month, cvv, EnabledTokenization"))
                    return
                }
                
                self.brands = brands
                self.number = number
                self.holder = holder
                self.year = year
                self.month = month
                self.cvv = cvv
                self.setStorePaymentDetailsMode = setStorePaymentDetailsMode
                
                self.openCustomUI(checkoutId: self.checkoutid, result1: result)
            }
            else {
                result(createDetailedError(code: "INVALID_PAYMENT_TYPE", message: "Invalid payment type", details: "Received type: \(self.type), Expected: ReadyUI or CustomUI"))
            }

        } else {
            result(createDetailedError(code: "METHOD_NOT_FOUND", message: "Method name not found", details: "Called method: \(call.method), Expected: gethyperpayresponse"))
        }
    }

    @IBAction func checkoutButtonAction(_ sender: UIButton) {
        // Set a delegate property for the OPPCheckoutProvider instance
        self.checkoutProvider?.delegate = self
    }
 
    // Implement a callback, it will be called after holder text field loses focus or Pay button is pressed
    public func checkoutProvider(
        _ checkoutProvider: OPPCheckoutProvider, validateCardHolder cardHolder: String?
    ) -> Bool {
        guard let cardHolder = cardHolder, !cardHolder.trimmingCharacters(in: .whitespaces).isEmpty
        else {
            logError("Card holder validation failed - empty or nil")
            return false
        }
        
        logError("Card holder validation successful")
        return true
    }

    private func openCheckoutUI(checkoutId: String,result1: @escaping FlutterResult) {
        logError("Opening CheckoutUI with checkoutId: \(checkoutId)")
        
        if self.mode == "live" {
            self.provider = OPPPaymentProvider(mode: OPPProviderMode.live)
            logError("Payment provider set to LIVE mode")
        }else{
            self.provider = OPPPaymentProvider(mode: OPPProviderMode.test)
            logError("Payment provider set to TEST mode")
        }
        
        DispatchQueue.main.async{
            let checkoutSettings = OPPCheckoutSettings()
            checkoutSettings.paymentBrands = self.brandsReadyUi;
            
            self.logError("Payment brands set: \(self.brandsReadyUi)")
            
            if(self.brandsReadyUi.contains("APPLEPAY")){
                self.logError("Configuring Apple Pay")
                
                let paymentRequest = OPPPaymentProvider.paymentRequest(withMerchantIdentifier: self.applePaybundel, countryCode: self.countryCode)
                paymentRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: self.companyName, amount: NSDecimalNumber(value: self.amount))]

                if #available(iOS 12.1.1, *) {
                    paymentRequest.supportedNetworks = [ PKPaymentNetwork.mada,PKPaymentNetwork.visa, PKPaymentNetwork.masterCard ]
                }
                else {
                    // Fallback on earlier versions
                    paymentRequest.supportedNetworks = [ PKPaymentNetwork.visa, PKPaymentNetwork.masterCard ]
                }
                checkoutSettings.applePayPaymentRequest = paymentRequest
                self.logError("Apple Pay configured successfully")
            }
            
            checkoutSettings.language = self.lang
            checkoutSettings.shopperResultURL = self.shopperResultURL+"://result"
            
            if self.setStorePaymentDetailsMode=="true"{
                checkoutSettings.storePaymentDetails = OPPCheckoutStorePaymentDetailsMode.prompt;
                self.logError("Store payment details mode enabled")
            }
            
            self.setThem(checkoutSettings: checkoutSettings, hexColorString: self.themColorHex)
            
            guard let checkoutProvider = OPPCheckoutProvider(paymentProvider: self.provider, checkoutID: checkoutId, settings: checkoutSettings) else {
                result1(self.createDetailedError(code: "CHECKOUT_PROVIDER_INIT_ERROR", message: "Failed to initialize checkout provider", details: "CheckoutID: \(checkoutId)"))
                return
            }
            
            self.checkoutProvider = checkoutProvider
            self.checkoutProvider?.delegate = self
            self.logError("Checkout provider initialized successfully")
            
            self.checkoutProvider?.presentCheckout(forSubmittingTransactionCompletionHandler: {
                (transaction, error) in
                self.logError("Checkout completion handler called")
                
                guard let transaction = transaction else {
                    self.handleTransactionError(transaction: nil, error: error, result: result1, context: "ReadyUI Checkout")
                    return
                }
                
                self.transaction = transaction
                self.logError("Transaction created with type: \(transaction.type.rawValue)")
                
                if transaction.type == .synchronous {
                    self.logError("Synchronous transaction completed successfully")
                    DispatchQueue.main.async {
                        result1("SYNC")
                    }
                }
                else if transaction.type == .asynchronous {
                    self.logError("Asynchronous transaction initiated")
                    NotificationCenter.default.addObserver(self, selector: #selector(self.didReceiveAsynchronousPaymentCallback), name: Notification.Name(rawValue: "AsyncPaymentCompletedNotificationKey"), object: nil)
                }
                else {
                    self.handleTransactionError(transaction: transaction, error: error, result: result1, context: "ReadyUI Transaction Processing")
                }
            }, cancelHandler: {
                self.logError("Payment cancelled by user")
                result1(self.createDetailedError(code: "PAYMENT_CANCELLED", message: "Payment was cancelled by user", details: nil))
            })
        }
    }

    private func openCustomUI(checkoutId: String,result1: @escaping FlutterResult) {
        logError("Opening CustomUI with checkoutId: \(checkoutId)")
        
        if self.mode == "live" {
            self.provider = OPPPaymentProvider(mode: OPPProviderMode.live)
        }else{
            self.provider = OPPPaymentProvider(mode: OPPProviderMode.test)
        }

        // Validate card details with detailed error messages
        if !OPPCardPaymentParams.isNumberValid(self.number, luhnCheck: true) {
            let error = createDetailedError(code: "INVALID_CARD_NUMBER", message: "Card number is invalid", details: "Card number: \(self.number.prefix(4))****")
            result1(error)
            return
        }
        else if !OPPCardPaymentParams.isHolderValid(self.holder) {
            let error = createDetailedError(code: "INVALID_CARD_HOLDER", message: "Card holder name is invalid", details: "Holder: \(self.holder)")
            result1(error)
            return
        }
        else if !OPPCardPaymentParams.isCvvValid(self.cvv) {
            let error = createDetailedError(code: "INVALID_CVV", message: "CVV is invalid", details: nil)
            result1(error)
            return
        }
        else if !OPPCardPaymentParams.isExpiryYearValid(self.year) {
            let error = createDetailedError(code: "INVALID_EXPIRY_YEAR", message: "Expiry year is invalid", details: "Year: \(self.year)")
            result1(error)
            return
        }
        else if !OPPCardPaymentParams.isExpiryMonthValid(self.month) {
            let error = createDetailedError(code: "INVALID_EXPIRY_MONTH", message: "Expiry month is invalid", details: "Month: \(self.month)")
            result1(error)
            return
        }
        else {
            do {
                let params = try OPPCardPaymentParams(checkoutID: checkoutId, paymentBrand: self.brands, holder: self.holder, number: self.number, expiryMonth: self.month, expiryYear: self.year, cvv: self.cvv)
                
                var isEnabledTokenization:Bool = false;
                if(self.setStorePaymentDetailsMode=="true"){
                    isEnabledTokenization=true;
                }
                params.isTokenizationEnabled=isEnabledTokenization;
                params.shopperResultURL = self.shopperResultURL+"://result"
                
                self.logError("Card payment params created successfully, tokenization: \(isEnabledTokenization)")
                
                self.transaction = OPPTransaction(paymentParams: params)
                self.provider.submitTransaction(self.transaction!) {
                    (transaction, error) in
                    
                    self.logError("Custom UI transaction submission completed")
                    
                    guard let transaction = self.transaction else {
                        self.handleTransactionError(transaction: nil, error: error, result: result1, context: "CustomUI Transaction Creation")
                        return
                    }
                    
                    if transaction.type == .asynchronous {
                        self.logError("Asynchronous transaction - opening Safari for 3DS")
                        guard let redirectURL = self.transaction?.redirectURL else {
                            result1(self.createDetailedError(code: "MISSING_REDIRECT_URL", message: "Missing redirect URL for 3DS authentication", details: nil))
                            return
                        }
                        
                        self.safariVC = SFSafariViewController(url: redirectURL)
                        self.safariVC?.delegate = self;
                        UIApplication.shared.windows.first?.rootViewController?.present(self.safariVC!, animated: true, completion: nil)
                    }
                    else if transaction.type == .synchronous {
                        self.logError("Synchronous transaction completed successfully")
                        result1("success")
                    }
                    else {
                        self.handleTransactionError(transaction: transaction, error: error, result: result1, context: "CustomUI Transaction Processing")
                    }
                }
            }
            catch let error as NSError {
                let flutterError = createDetailedError(code: "CARD_PARAMS_ERROR", message: error.localizedDescription, details: "Error Code: \(error.code), Domain: \(error.domain)")
                result1(flutterError)
            }
        }
    }

    @objc func didReceiveAsynchronousPaymentCallback(result: @escaping FlutterResult) {
        logError("Asynchronous payment callback received")
        NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "AsyncPaymentCompletedNotificationKey"), object: nil)
        
        if self.type == "ReadyUI" || self.type=="APPLEPAY"||self.type=="StoredCards"{
            self.checkoutProvider?.dismissCheckout(animated: true) {
                DispatchQueue.main.async {
                    self.logError("ReadyUI checkout dismissed, returning success")
                    result("success")
                }
            }
        }
        else {
            self.safariVC?.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.logError("Safari VC dismissed, returning success")
                    result("success")
                }
            }
        }
    }
    
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        logError("Application opened with URL: \(url.absoluteString)")
        var handler:Bool = false
        if url.scheme?.caseInsensitiveCompare( self.shopperResultURL) == .orderedSame {
            logError("URL scheme matches shopper result URL")
            didReceiveAsynchronousPaymentCallback(result: self.Presult!)
            handler = true
        } else {
            logError("URL scheme does not match. Expected: \(self.shopperResultURL), Got: \(url.scheme ?? "nil")")
        }

        return handler
    }

    func createalart(titletext:String,msgtext:String){
        logError("Showing alert - Title: \(titletext), Message: \(msgtext)")
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: titletext, message:
                                                    msgtext, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .default,handler: {
                (action) in alertController.dismiss(animated: true, completion: nil)
            }))
            UIApplication.shared.delegate?.window??.rootViewController?.present(alertController, animated: true, completion: nil)
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        logError("Apple Pay authorization finished")
        controller.dismiss(animated: true, completion: nil)
    }
    
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {
        logError("Apple Pay payment authorized")
        
        do {
            let params = try OPPApplePayPaymentParams(checkoutID: self.checkoutid, tokenData: payment.token.paymentData)
            self.transaction = OPPTransaction(paymentParams: params)
            
            self.provider.submitTransaction(self.transaction!, completionHandler: {
                (transaction, error) in
                if let error = error {
                    self.logError("Apple Pay transaction failed", error: error)
                    completion(.failure)
                    self.Presult?(self.createDetailedError(code: "APPLEPAY_ERROR", message: "Apple Pay transaction failed", details: error.localizedDescription))
                }
                else {
                    self.logError("Apple Pay transaction successful")
                    completion(.success)
                    self.Presult?("success")
                }
            })
        } catch let error {
            logError("Apple Pay params creation failed", error: error)
            completion(.failure)
            self.Presult?(createDetailedError(code: "APPLEPAY_PARAMS_ERROR", message: "Failed to create Apple Pay parameters", details: error.localizedDescription))
        }
    }
    
    func decimal(with string: String) -> NSDecimalNumber {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        return formatter.number(from: string) as? NSDecimalNumber ?? 0
    }

    func setThem( checkoutSettings :OPPCheckoutSettings,hexColorString :String){
        logError("Setting theme with color: \(hexColorString)")
        // General colors of the checkout UI
        checkoutSettings.theme.confirmationButtonColor = UIColor(red:0,green:0.75,blue:0,alpha:1);
        checkoutSettings.theme.navigationBarBackgroundColor = UIColor(hexString:hexColorString);
        checkoutSettings.theme.cellHighlightedBackgroundColor = UIColor(hexString:hexColorString);
        checkoutSettings.theme.accentColor = UIColor(hexString:hexColorString);
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}