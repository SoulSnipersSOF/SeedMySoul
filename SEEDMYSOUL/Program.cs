using System;
using System.Linq;
using System.Windows.Forms;

namespace SEEDMYSOUL
{
    internal static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            bool auto = args.Any(a => a.Equals("--auto",
                                 StringComparison.OrdinalIgnoreCase));

            ApplicationConfiguration.Initialize();   // .NET 6/8 WinForms boilerplate
            Application.Run(new Form1(auto));
        }
    }
}
