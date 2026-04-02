'use strict';

var app = angular.module('swiftCinemas', ['ngRoute']);

/* ================================================================
   HMAC-SHA512 HTTP interceptor (same logic as existing script.js)
   ================================================================ */
app.config(function ($httpProvider) {
    $httpProvider.interceptors.push(function ($q) {
        return {
            request: function (config) {
                var publicUrls = [
                    '/mbooks-1/rest/book/movies',
                    '/mbooks-1/rest/book/locations'
                ];
                var isPublic = publicUrls.indexOf(config.url) !== -1 ||
                    config.url.indexOf('/mbooks-1/rest/book/venue/') === 0 ||
                    config.url.indexOf('/mbooks-1/rest/book/dates/') === 0 ||
                    config.url.indexOf('/mbooks-1/rest/book/seats/') === 0 ||
                    config.url.indexOf('/login/') === 0;
                if (!isPublic) {
                    if (!localStorage.sessionToken_) {
                        console.warn('No sessionToken to sign the request');
                        return $q.reject('No sessionToken to sign the request!');
                    }
                }
                config.headers['X-URL'] = config.url;
                return config || $q.when(config);
            },
            responseError: function (r) { return $q.reject(r); },
            requestError: function (r) { console.log(r); return $q.reject(r); },
            response: function (r) { return r || $q.when(r); }
        };
    });

    $httpProvider.defaults.transformRequest.push(function (data, headersGetter) {
        var guid = function () {
            var nav = window.navigator, scr = window.screen;
            var g = nav.mimeTypes.length;
            g += nav.userAgent.replace(/\D+/g, '');
            g += nav.plugins.length;
            g += scr.height || '';
            g += scr.width || '';
            g += scr.pixelDepth || '';
            return g;
        };
        var uuid = guid();
        var enc = encodeURIComponent(uuid);
        var t = new Date().getTime();
        var hmacSec = CryptoJS.HmacSHA512(headersGetter()['X-URL'], enc);
        localStorage.hmacSecret = CryptoJS.enc.Base64.stringify(hmacSec);
        var hash = CryptoJS.HmacSHA512(headersGetter()['X-URL'] + ':' + enc + ':' + t, hmacSec);
        headersGetter()['X-HMAC-HASH'] = CryptoJS.enc.Base64.stringify(hash);
        headersGetter()['X-MICRO-TIME'] = t;
        headersGetter()['X-Device'] = enc;
        headersGetter()['X-URL'] = '';
        if (localStorage.sessionToken_) {
            headersGetter()['X-Token'] = localStorage.sessionToken_;
        }
    });

    $httpProvider.defaults.headers.get = { 'My-Headers': 'value' };
});

/* ================================================================
   Route configuration — hashbang mode
   ================================================================ */
app.config(function ($routeProvider) {
    $routeProvider
        .when('/', {
            templateUrl: 'templates/movies.html',
            controller: 'MoviesController'
        })
        .when('/venues-list', {
            templateUrl: 'templates/venues-list.html',
            controller: 'VenuesListController'
        })
        .when('/venue-movies/:locationId', {
            templateUrl: 'templates/venue-movies.html',
            controller: 'VenueMoviesController'
        })
        .when('/venues/:movieId', {
            templateUrl: 'templates/venues.html',
            controller: 'VenuesController'
        })
        .when('/dates/:locationId/:movieId', {
            templateUrl: 'templates/dates.html',
            controller: 'DatesSeatsController'
        })
        .when('/checkout', {
            templateUrl: 'templates/checkout.html',
            controller: 'CheckoutController'
        })
        .when('/purchases', {
            templateUrl: 'templates/purchases.html',
            controller: 'PurchasesController'
        })
        .when('/purchases/:purchaseId', {
            templateUrl: 'templates/purchase-detail.html',
            controller: 'PurchaseDetailController'
        })
        .otherwise({ redirectTo: '/' });
});

/* ================================================================
   Global navigation helper — uses $location to avoid full reloads
   ================================================================ */
app.run(function ($rootScope, $location) {
    $rootScope.go = function (path) {
        $location.path(path);
    };
});

/* ================================================================
   Image helper
   ================================================================ */
var IMG_BASE = '/simple-service-webapp/webapi/myresource';

/* ================================================================
   MoviesController — movie grid
   ================================================================ */
app.controller('MoviesController', function ($scope, $http) {
    $scope.movies = [];
    $scope.loading = true;
    $scope.loadError = false;
    $scope.search = '';

    $http({
        method: 'GET',
        url: '/mbooks-1/rest/book/movies',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-Token': 'client-secret' }
    }).success(function (data, status, headers) {
        localStorage.sessionToken_ = headers('APIKEY');
        $scope.movies = data.movies || [];
        $scope.loading = false;
    }).error(function () {
        $scope.loadError = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;
});

/* ================================================================
   VenuesController — location selection for a movie
   ================================================================ */
app.controller('VenuesController', function ($scope, $http, $routeParams) {
    $scope.movieId = $routeParams.movieId;
    $scope.locations = [];
    $scope.loading = true;
    $scope.error = false;

    $http({
        method: 'GET',
        url: '/mbooks-1/rest/book/venue/v2/' + $scope.movieId,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
    }).success(function (data) {
        $scope.locations = data.locations || [];
        $scope.loading = false;
    }).error(function () {
        $scope.error = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;
});

/* ================================================================
   DatesSeatsController — date picker + seat map with multi-select
   ================================================================ */
app.controller('DatesSeatsController', function ($scope, $http, $routeParams, $location) {
    $scope.locationId = $routeParams.locationId;
    $scope.movieId = $routeParams.movieId;
    $scope.dates = [];
    $scope.seats = [];
    $scope.selectedDate = '';
    $scope.loading = true;
    $scope.seatsLoading = false;
    $scope.error = false;

    // Fetch dates
    $http({
        method: 'GET',
        url: '/mbooks-1/rest/book/dates/' + $scope.locationId + '/' + $scope.movieId,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
    }).success(function (data) {
        $scope.dates = data.dates || [];
        $scope.loading = false;
    }).error(function () {
        $scope.error = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;

    // When a date is selected, fetch seats
    $scope.onDateChange = function () {
        if (!$scope.selectedDate) return;
        $scope.seats = [];
        $scope.seatsLoading = true;

        $http({
            method: 'GET',
            url: '/mbooks-1/rest/book/seats/' + $scope.selectedDate,
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
        }).success(function (data) {
            var raw = data.seatsforscreen || [];
            raw.forEach(function (s) { s.selected = false; });
            $scope.seats = raw;
            $scope.seatsLoading = false;
        }).error(function () {
            $scope.seatsLoading = false;
        });
    };

    // Group seats into rows for display
    $scope.getSeatRows = function () {
        var rows = {};
        $scope.seats.forEach(function (s) {
            if (!rows[s.seatRow]) rows[s.seatRow] = [];
            rows[s.seatRow].push(s);
        });
        // Sort rows and seats within each row
        var sorted = [];
        Object.keys(rows).sort(function (a, b) { return parseInt(a) - parseInt(b); }).forEach(function (k) {
            rows[k].sort(function (a, b) { return a.seatNumber.localeCompare(b.seatNumber); });
            sorted.push({ row: k, seats: rows[k] });
        });
        return sorted;
    };

    $scope.toggleSeat = function (seat) {
        if (seat.isReserved === '1') return;
        seat.selected = !seat.selected;
    };

    $scope.getSelectedSeats = function () {
        return $scope.seats.filter(function (s) { return s.selected; });
    };

    $scope.getTotal = function () {
        return $scope.getSelectedSeats().length * 10;
    };

    $scope.proceedToCheckout = function () {
        var selected = $scope.getSelectedSeats();
        // iOS client uses seatNumber (e.g. "A1") with trailing dash: "A1-B2-C3-"
        // Backend DAO.bookTickets queries by seatNumber, NOT seatId
        var seatNumbers = selected.map(function (s) { return s.seatNumber; }).join('-') + '-';
        var displaySeats = selected.map(function (s) { return s.seatNumber; }).join(', ');
        // Build the JSON structure that fullcheckout2 expects (same as iOS):
        // {"seatsToBeReserved":[{"screeningDateId":"N","seat":"A1-B2-C3-"}]}
        var seatsPayload = JSON.stringify({
            seatsToBeReserved: [{
                screeningDateId: $scope.selectedDate,
                seat: seatNumbers
            }]
        });
        sessionStorage.setItem('checkout_seats', displaySeats);
        sessionStorage.setItem('checkout_seats_payload', seatsPayload);
        sessionStorage.setItem('checkout_total', selected.length * 10);
        sessionStorage.setItem('checkout_screeningDateId', $scope.selectedDate);
        $location.path('/checkout');
    };
});

/* ================================================================
   CheckoutController — Braintree Drop-in + payment
   ================================================================ */
app.controller('CheckoutController', function ($scope, $http) {
    $scope.selectedSeatIds = sessionStorage.getItem('checkout_seats') || '';
    $scope.totalAmount = sessionStorage.getItem('checkout_total') || '0';
    var screeningDateId = sessionStorage.getItem('checkout_screeningDateId') || '';
    var seatsPayload = sessionStorage.getItem('checkout_seats_payload') || '';

    $scope.dropinReady = false;
    $scope.dropinError = null;
    $scope.paymentSuccess = null;
    $scope.paymentError = null;
    $scope.paymentProcessing = false;

    var dropinInstance = null;

    // 1) Fetch client token
    $http({
        method: 'GET',
        url: '/login/CheckOut',
        headers: { Accept: 'application/json' }
    }).success(function (data) {
        var clientToken = data.clientToken;
        if (!clientToken) {
            $scope.dropinError = 'No client token received. Please log in first.';
            return;
        }
        if (typeof braintree === 'undefined' || !braintree.dropin) {
            $scope.dropinError = 'Payment library failed to load. Please refresh.';
            return;
        }
        braintree.dropin.create({
            authorization: clientToken,
            container: '#dropin-container',
            card: {
                overrides: {
                    styles: {
                        input: { 'font-size': '14px', color: '#333' },
                        'input.invalid': { color: '#e94560' },
                        'input.valid': { color: '#2e7d32' }
                    }
                }
            }
        }, function (err, instance) {
            $scope.$apply(function () {
                if (err) { $scope.dropinError = 'Payment form error: ' + err.message; return; }
                dropinInstance = instance;
                $scope.dropinReady = true;
            });
        });
    }).error(function () {
        $scope.dropinError = 'Could not connect to payment service. Are you logged in?';
    });

    // 2) Submit payment
    $scope.submitPayment = function () {
        if (!dropinInstance) return;
        $scope.paymentProcessing = true;
        $scope.paymentError = null;
        $scope.paymentSuccess = null;

        dropinInstance.requestPaymentMethod(function (err, payload) {
            if (err) {
                $scope.$apply(function () {
                    $scope.paymentError = 'Please complete the payment form.';
                    $scope.paymentProcessing = false;
                });
                return;
            }
            // iOS client sends orderId as current time in millis
            var postData = 'payment_method_nonce=' + encodeURIComponent(payload.nonce) +
                '&orderId=' + encodeURIComponent(new Date().getTime()) +
                '&seatsToBeReserved=' + encodeURIComponent(seatsPayload);

            $http({
                method: 'POST',
                url: '/login/CheckOut',
                data: postData,
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
            }).success(function (data) {
                $scope.paymentProcessing = false;
                if (data.Success === 'true') {
                    $scope.paymentSuccess = 'Transaction ' + (data.Status || 'completed') + '. Auth code: ' + (data.AuthCode || 'N/A');
                    sessionStorage.removeItem('checkout_seats');
                    sessionStorage.removeItem('checkout_seats_payload');
                    sessionStorage.removeItem('checkout_total');
                    sessionStorage.removeItem('checkout_screeningDateId');
                } else {
                    $scope.paymentError = 'Transaction failed: ' + (data.ResponseText || 'Unknown error');
                }
            }).error(function () {
                $scope.paymentProcessing = false;
                $scope.paymentError = 'Payment request failed. Please try again.';
            });
        });
    };
});

/* ================================================================
   VenuesListController — browse all cinema locations
   ================================================================ */
app.controller('VenuesListController', function ($scope, $http) {
    $scope.locations = [];
    $scope.loading = true;
    $scope.error = false;

    $http({
        method: 'GET',
        url: '/mbooks-1/rest/book/locations',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
    }).success(function (data) {
        $scope.locations = data.locations || [];
        $scope.loading = false;
    }).error(function () {
        $scope.error = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;
});

/* ================================================================
   VenueMoviesController — movies screening at a selected venue
   ================================================================ */
app.controller('VenueMoviesController', function ($scope, $http, $routeParams) {
    $scope.locationId = $routeParams.locationId;
    $scope.movies = [];
    $scope.venueName = '';
    $scope.venuePicture = '';
    $scope.loading = true;
    $scope.error = false;

    $http({
        method: 'GET',
        url: '/mbooks-1/rest/book/venue/movies?locationId=' + $scope.locationId,
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' }
    }).success(function (data) {
        $scope.movies = data.movies || [];
        var venues = data.venue || [];
        if (venues.length > 0) {
            $scope.venueName = venues[0].name || '';
            $scope.venuePicture = venues[0].venues_picture || '';
        }
        $scope.loading = false;
    }).error(function () {
        $scope.error = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;
});

/* ================================================================
   PurchasesController — purchase history list
   ================================================================ */
app.controller('PurchasesController', function ($scope, $http) {
    $scope.purchases = [];
    $scope.loading = true;
    $scope.error = false;

    $http({
        method: 'GET',
        url: '/login/GetAllPurchases',
        headers: { Accept: 'application/json' }
    }).success(function (data) {
        $scope.purchases = data.purchases || [];
        $scope.loading = false;
    }).error(function () {
        $scope.error = true;
        $scope.loading = false;
    });

    $scope.imgBase = IMG_BASE;

    $scope.deletePurchase = function (purchaseId) {
        if (!confirm('Delete this entire purchase? This cannot be undone.')) return;
        $http({
            method: 'POST',
            url: '/login/ManagePurchases',
            data: 'purchaseId=' + encodeURIComponent(purchaseId),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        }).success(function () {
            $scope.purchases = $scope.purchases.filter(function (p) {
                return p.purchaseId !== purchaseId;
            });
        }).error(function () {
            alert('Failed to delete purchase. Please try again.');
        });
    };
});

/* ================================================================
   PurchaseDetailController — tickets for a specific purchase
   ================================================================ */
app.controller('PurchaseDetailController', function ($scope, $http, $routeParams) {
    $scope.purchaseId = $routeParams.purchaseId;
    $scope.tickets = [];
    $scope.loading = true;
    $scope.error = false;
    $scope.cancelSuccess = null;
    $scope.cancelError = null;

    var loadTickets = function () {
        $http({
            method: 'GET',
            url: '/login/ManagePurchases?purchaseId=' + $scope.purchaseId,
            headers: { Accept: 'application/json' }
        }).success(function (data) {
            $scope.tickets = data.tickets || [];
            $scope.loading = false;
        }).error(function () {
            $scope.error = true;
            $scope.loading = false;
        });
    };

    loadTickets();

    $scope.imgBase = IMG_BASE;

    $scope.getSelectedTickets = function () {
        return $scope.tickets.filter(function (t) { return t.selected; });
    };

    $scope.toggleTicket = function (ticket) {
        ticket.selected = !ticket.selected;
    };

    $scope.cancelSelected = function () {
        var selected = $scope.getSelectedTickets();
        if (selected.length === 0) return;
        if (!confirm('Cancel ' + selected.length + ' ticket(s)?')) return;

        var ticketIds = selected.map(function (t) { return t.ticketId; });
        // Backend expects ticketsToBeCancelled as JSON: {"ticketIds": [1, 2, 3]}
        var ticketsPayload = JSON.stringify({ ticketIds: ticketIds });
        $scope.cancelSuccess = null;
        $scope.cancelError = null;

        $http({
            method: 'POST',
            url: '/login/ManagePurchases',
            data: 'purchaseId=' + encodeURIComponent($scope.purchaseId) +
                  '&ticketsToBeCancelled=' + encodeURIComponent(ticketsPayload),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        }).success(function () {
            $scope.cancelSuccess = selected.length + ' ticket(s) cancelled successfully.';
            $scope.loading = true;
            loadTickets();
        }).error(function () {
            $scope.cancelError = 'Failed to cancel tickets. Please try again.';
        });
    };
});

