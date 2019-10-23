using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using EmbeddedDemo.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Rest;
using Microsoft.PowerBI.Api.V2;
using Microsoft.PowerBI.Api.V2.Models;

namespace EmbeddedDemo.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly IConfiguration _configuration;
        private readonly string AuthorityUrl;
        private readonly string ResourceUrl;
        private readonly string ApplicationId;
        private readonly string ApiUrl;
        private readonly string WorkspaceId;
        private readonly string ReportId;
        private readonly string ApplicationSecret;
        private readonly string Tenant;

        public HomeController(ILogger<HomeController> logger, IConfiguration configuration)
        {
            _configuration = configuration;
            _logger = logger;

            AuthorityUrl = _configuration["AuthorityUrl"];
            ResourceUrl = _configuration["ResourceUrl"];
            ApplicationId = _configuration["ApplicationId"];
            ApiUrl = _configuration["ApiUrl"];
            WorkspaceId = _configuration["WorkspaceId"];
            ReportId = _configuration["ReportId"];
            ApplicationSecret = _configuration["ApplicationSecret"];
            Tenant = _configuration["Tenant"];
        }

        public async Task<IActionResult> Index()
        {
            var embedConfig = new EmbedConfig();

            var tokenCredentials = await GetTokenCredentials();

            // Create a Power BI Client object. It will be used to call Power BI APIs.
            using (var client = new PowerBIClient(new Uri(ApiUrl), tokenCredentials))
            {
                // Get a list of reports.
                var reports = await client.Reports.GetReportsInGroupAsync(Guid.Parse(WorkspaceId));

                // Get specific report.
                var report = reports.Value.FirstOrDefault(r => r.Id.Equals(Guid.Parse(ReportId)));

                // Generate the Embedd token
                var generateTokenRequestParameters = new GenerateTokenRequest(accessLevel: "view");
                var tokenResponse = await client.Reports.GenerateTokenInGroupAsync(Guid.Parse(WorkspaceId), report.Id, generateTokenRequestParameters);


                embedConfig.EmbedToken = tokenResponse;
                embedConfig.EmbedUrl = report.EmbedUrl;
                embedConfig.Id = report.Id.ToString();

            }

            return View(embedConfig);
        }

        private async Task<TokenCredentials> GetTokenCredentials()
        {
            // Authenticate using created credentials
            AuthenticationResult authenticationResult = null;
            authenticationResult = await DoAuthentication();
            return new TokenCredentials(authenticationResult.AccessToken, "Bearer");
        }

        private async Task<AuthenticationResult> DoAuthentication()
        {
            AuthenticationResult authenticationResult = null;

            // For app only authentication, we need the specific tenant id in the authority url
            var tenantSpecificURL = AuthorityUrl.Replace("common", Tenant);
            var authenticationContext = new AuthenticationContext(tenantSpecificURL);

            // Authentication using app credentials
            var credential = new ClientCredential(ApplicationId, ApplicationSecret);
            authenticationResult = await authenticationContext.AcquireTokenAsync(ResourceUrl, credential);

            return authenticationResult;
        }
    }
}
