import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:web/web.dart' as web;

class RazorpayService {
  RazorpayService() {
    // WEB PORT: on web the razorpay_flutter method channel does not exist;
    // open() drives the browser Razorpay Checkout (checkout.js) instead.
    // The mobile SDK subscriptions stay exactly as they were.
    if (kIsWeb) {
      return;
    }
    _razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleWallet);
  }

  final Razorpay _razorpay = Razorpay();

  void Function(PaymentSuccessResponse)? onSuccess;
  void Function(PaymentFailureResponse)? onFailure;
  void Function(ExternalWalletResponse)? onExternalWallet;

  Completer<void>? _checkoutJsLoading;

  void open(RazorpayOptions options) {
    if (kIsWeb) {
      unawaited(_openWebCheckout(options));
      return;
    }
    _razorpay.open(options.toMap());
  }

  void dispose() {
    if (kIsWeb) {
      return;
    }
    _razorpay.clear();
  }

  // ── WEB: Razorpay Checkout (checkout.js) ──────────────────────────────

  /// Loads https://checkout.razorpay.com/v1/checkout.js once, then opens
  /// the browser checkout modal with the same options the mobile SDK would
  /// receive. Success / error / dismissal map onto the exact razorpay_flutter
  /// response types the mobile flow hands to payment_provider, so nothing
  /// above this class knows or cares which checkout ran.
  Future<void> _openWebCheckout(RazorpayOptions options) async {
    try {
      await _ensureCheckoutJsLoaded();
    } catch (_) {
      onFailure?.call(
        PaymentFailureResponse(
          Razorpay.NETWORK_ERROR,
          'Unable to reach the payment gateway. Please check your connection.',
          null,
        ),
      );
      return;
    }

    final ctor = globalContext['Razorpay'];
    if (ctor == null || ctor.isUndefinedOrNull) {
      onFailure?.call(
        PaymentFailureResponse(
          Razorpay.UNKNOWN_ERROR,
          'Payment gateway failed to load.',
          null,
        ),
      );
      return;
    }

    final checkoutOptions = <String, Object?>{
      'key': options.key,
      'amount': options.amount,
      'order_id': options.razorpayOrderId,
      'name': options.name,
      'description': options.description,
      if (options.contact != null ||
          options.email != null ||
          options.prefillName != null)
        'prefill': <String, Object?>{
          if (options.contact != null) 'contact': options.contact,
          if (options.email != null) 'email': options.email,
          if (options.prefillName != null) 'name': options.prefillName,
        },
      'theme': <String, Object?>{'color': options.themeColorHex},
      // Success handler — mirrors razorpay_flutter's payment.success payload.
      'handler': ((JSObject response) {
        final data = _mapFromJs(response);
        onSuccess?.call(
          PaymentSuccessResponse(
            data['razorpay_payment_id'] as String?,
            data['razorpay_order_id'] as String?,
            data['razorpay_signature'] as String?,
            data,
          ),
        );
      }).toJS,
      // Modal dismissed without completing — Razorpay.PAYMENT_CANCELLED (2)
      // is what the mobile SDK reports for a cancelled checkout, and
      // payment_provider branches on exactly that code.
      'modal': <String, Object?>{
        'ondismiss': (() {
          onFailure?.call(
            PaymentFailureResponse(
              Razorpay.PAYMENT_CANCELLED,
              'Payment cancelled by user',
              null,
            ),
          );
        }).toJS,
      },
    }.jsify()!;

    final rzp = (ctor as JSFunction).callAsConstructor<JSObject>(
      checkoutOptions,
    );

    // payment.error carries { error: { code, description, ... } }.
    rzp.callMethod(
      'on'.toJS,
      'payment.error'.toJS,
      ((JSObject response) {
        final data = _mapFromJs(response);
        final error = data['error'];
        final message = error is Map
            ? (error['description'] as String? ?? 'Payment failed')
            : 'Payment failed';
        onFailure?.call(
          PaymentFailureResponse(Razorpay.INVALID_OPTIONS, message,
            error is Map ? Map<dynamic, dynamic>.from(error) : null),
        );
      }).toJS,
    );

    rzp.callMethod('open'.toJS);
  }

  Future<void> _ensureCheckoutJsLoaded() {
    final existingGlobal = globalContext['Razorpay'];
    if (existingGlobal != null && !existingGlobal.isUndefinedOrNull) {
      return Future<void>.value();
    }
    final existing = _checkoutJsLoading;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<void>();
    _checkoutJsLoading = completer;

    final script = web.HTMLScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..async = true;
    script.onload = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;
    script.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('checkout.js failed to load'),
        );
      }
    }).toJS;
    web.document.head?.appendChild(script);

    return completer.future;
  }

  Map<String, Object?> _mapFromJs(JSObject object) {
    final dartified = object.dartify();
    if (dartified is Map) {
      return Map<String, Object?>.from(dartified);
    }
    return <String, Object?>{};
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    onSuccess?.call(response);
  }

  void _handleFailure(PaymentFailureResponse response) {
    onFailure?.call(response);
  }

  void _handleWallet(ExternalWalletResponse response) {
    onExternalWallet?.call(response);
  }
}

class RazorpayOptions {
  const RazorpayOptions({
    required this.key,
    required this.amount,
    required this.razorpayOrderId,
    required this.name,
    required this.description,
    required this.themeColorHex,
    this.contact,
    this.email,
    this.prefillName,
  });

  final String key;
  final int amount;
  final String razorpayOrderId;
  final String name;
  final String description;
  final String themeColorHex;
  final String? contact;
  final String? email;
  final String? prefillName;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'amount': amount,
      'order_id': razorpayOrderId,
      'name': name,
      'description': description,
      'prefill': <String, dynamic>{
        'contact': contact,
        'email': email,
        'name': prefillName,
      }..removeWhere((key, value) => value == null || value == ''),
      'theme': <String, dynamic>{
        'color': themeColorHex,
      },
    };
  }
}
