using Microsoft.PowerBI.Api.V2.Models;
using System;

namespace EmbeddedDemo.Models
{
    public class EmbedConfig
    {
        public string Id { get; set; }

        public string EmbedUrl { get; set; }

        public EmbedToken EmbedToken { get; set; }

        public int MinutesToExpiration
        {
            get
            {
                var minutesToExpiration = EmbedToken.Expiration.Subtract(DateTime.UtcNow);
                return (int)minutesToExpiration.TotalMinutes;
            }
        }

    }
}
