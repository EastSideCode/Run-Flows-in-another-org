public with sharing class RunFlowOnAnotherOrg {

    static final String RUN_FLOW_URL = '{0}/services/data/v51.0/actions/custom/flow/{1}';
    static final String GET_TOKEN_URL = '{0}/services/oauth2/token';
    static final String ERROR_MESSAGE = 'error';
    static final String SUCCESS_MESSAGE = 'success';
    static final String POST_METHOD = 'POST';

    @InvocableMethod(label='Run Flow on Another Org' description='Run Flow on Another Org' callout=true configurationEditor='c:runFlowOnAnotherOrgCPE')
    static public List<Response> execute(List<Request> requestList) {
        List<Response> responseList = new List<Response>();
        for (Request request : requestList) {
            Response resp = new Response();
            if (request.useFutureMethod) {
                launchFuture(JSON.serialize(request));
            } else {
                HTTPResponse res = sendRequest(request);
            
                if (res.getStatusCode() == 200) {
                    resp.result = SUCCESS_MESSAGE;
                } else {
                    resp.result = ERROR_MESSAGE;
                }
                responseList.add(resp);
            }
        }
        return responseList;
    }

    static HttpResponse sendRequest(Request request) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(String.format(RUN_FLOW_URL, new List<String>{request.baseOrgURL, request.flowName}));
        req.setMethod(POST_METHOD);
        String accessToken = getAccessToken(request);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        String postBody = '';
        if (String.isNotEmpty(request.inputsJSON)) {
            List<InputParam> inputList = (List<InputParam>) JSON.deserialize(request.inputsJSON, List<InputParam>.class);
            Map<String, String> inputMap = new Map<String, String>();

            for (InputParam param : inputList) {
                if (String.isNotBlank(param.key)) {
                    inputMap.put(param.key, param.value);
                }                 
            }
            if (inputMap.size() > 0) {
                postBody += '{ "inputs" :  ' + JSON.serialize(new List<Object>{inputMap}) + ' }';
            }
        }
        req.setBody(postBody);
        Http http = new Http();
        HTTPResponse res = http.send(req);
        return res;
    }

    static String getAccessToken(Request request) {
        String assertion = createJwtAssertion(request);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(String.format(GET_TOKEN_URL, new List<String>{request.baseOrgURL}));
        req.setMethod(POST_METHOD);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8') + 
                    '&assertion=' + EncodingUtil.urlEncode(assertion, 'UTF-8'));
        
        Http http = new Http();
        HTTPResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('access_token');
        }
        
        return '';
    }

    static String createJwtAssertion(Request request) {
        Map<String, String> header = new Map<String, String>();
        header.put('alg', 'RS256');

        Map<String, String> body = new Map<String, String>();
        body.put('iss', request.consumerKey);
        body.put('prn', request.jwtUsername);
        body.put('aud', request.baseOrgURL);
        body.put('exp', String.valueOf(System.currentTimeMillis() / 1000 + 3600));

        String headerEncoded = base64UrlEncode(Blob.valueOf(JSON.serialize(header)));
        String bodyEncoded = base64UrlEncode(Blob.valueOf(JSON.serialize(body)));

        String token = headerEncoded + '.' + bodyEncoded;
        String signature = base64UrlEncode(Crypto.signWithCertificate('RSA-SHA256', Blob.valueOf(token), request.jwtSigningCertificateName));

        return token + '.' + signature;
    }

    static String base64UrlEncode(Blob b) {
        return EncodingUtil.base64Encode(b)
            .replace('+', '-')
            .replace('/', '_')
            .remove('=');
    }

    @future(callout=true)
    private static void launchFuture(String requestJSON) {
        Request request = (Request) JSON.deserialize(requestJSON, Request.class);
        sendRequest(request);
    }

    public class Request {
        @InvocableVariable(label='Base URL of the org' required=true)
        public String baseOrgURL;

        @InvocableVariable(label='Consumer Key' required=true)
        public String consumerKey;

        @InvocableVariable(label='JWT Username' required=true)
        public String jwtUsername;

        @InvocableVariable(label='JWT Signing Certificate Name' required=true)
        public String jwtSigningCertificateName;

        @InvocableVariable(label='Name of the flow' required=true)
        public String flowName;

        @InvocableVariable
        public Boolean useFutureMethod = false;

        @InvocableVariable(label='inputsJSON')
        public String inputsJSON;
    }

    public class Response {
        @InvocableVariable
        public String result;
    }

    private class InputParam {
        private String key;
        private String value;
    }
}
