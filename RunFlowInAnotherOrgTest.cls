@isTest
public with sharing class RunFlowOnAnotherOrgTest {
    @isTest
    static void executeTest() {
        RunFlowOnAnotherOrg.Request request = new RunFlowOnAnotherOrg.Request();
        Test.setMock(HttpCalloutMock.class, new RunFlowOnAnotherOrgMock());
        request.baseOrgURL = 'https://login.salesforce.com';
        request.consumerKey = 'consumerkey';
        request.jwtUsername = 'user@example.com';
        request.jwtSigningCertificateName = 'TestCert';
        request.flowName = 'run_Flow';
        request.inputsJSON = '[{"key" : "key", "value" : "value"}]';
        request.useFutureMethod = false;

        RunFlowOnAnotherOrg.Response response = RunFlowOnAnotherOrg.execute(new List<RunFlowOnAnotherOrg.Request>{request})[0];
        System.assertEquals('success', response.result);

        //run future method
        Test.startTest();
        request.useFutureMethod = true;
        response = RunFlowOnAnotherOrg.execute(new List<RunFlowOnAnotherOrg.Request>{request})[0];
        Test.stopTest();
    }

    public class RunFlowOnAnotherOrgMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            // Return access token for auth request, success for flow request
            if (req.getEndpoint().contains('/oauth2/token')) {
                res.setBody('{"access_token":"mock_token_12345"}');
            } else {
                res.setBody('{"example":"test"}');
            }
            
            res.setStatusCode(200);
            return res;
        }
    }
}
