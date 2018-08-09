using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;
using CrystalDecisions.ReportSource;
using CrystalDecisions.CrystalReports.Engine;

namespace ReportVersions
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        private void btnGet_Click(object sender, RoutedEventArgs e)
        {
            FetchVersions();
        }

        void FetchVersions()
        {
            this.Cursor = Cursors.Wait;
            ReportDocument doc = new ReportDocument();
            string path = txtRptDir.Text;
            string outputFile = path + txtFile.Text;
            string[] files = Directory.GetFiles(path);
            string fileName, rptTitle, rptVersion;

            using (StreamWriter sw = new StreamWriter(outputFile))
            {

                foreach (var file in files)
                {
                    
                        doc.Load(file);

                        FileInfo fi = new FileInfo(file);

                        fileName = fi.Name;
                        rptTitle = doc.SummaryInfo.ReportTitle;
                        rptVersion = doc.SummaryInfo.ReportComments;

                        sw.WriteLine(fileName + "," + rptTitle + ", " + rptVersion);
                    
                }
            }

            this.Cursor = Cursors.Arrow;

            MessageBox.Show("Done!");
        }

        private void btnCancel_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Shutdown();
        }
    }
}
