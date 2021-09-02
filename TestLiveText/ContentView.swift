//
//  ContentView.swift
//  TestLiveText
//
//  Created by Thiago Medeiros on 01/09/21.
//

import SwiftUI

struct ContentView: View {
    @State private var recognizedText = "Tap button to start scanning"
    @State private var showingScanningView = false
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.gray.opacity(0.2))

                        Text(recognizedText)
                            .padding()
                    }
                    .padding()
                }

                Spacer()

                HStack {
                    Spacer()

                    NavigationLink(
                        destination: ZStack {
                                LiveTextViewController(recognizedText: $recognizedText)
                                    .border(Color.red)
//                                    .ignoresSafeArea(.all, edges: .bottom)

                                Text(recognizedText)
                                    .padding()
                                    .offset(y: 250)

                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(.blue.opacity(0.75))
                                    .offset(y: 55)
                        }
                        .navigationBarTitle("")
                        .navigationBarHidden(true),
                        label: {
//                            Button(action: {
//                                self.showingScanningView = true
//                            }) {
                                Text("Start Scanning")
                                    .padding()
                                    .background(Capsule().fill(Color.blue))
//                            }
                            .foregroundColor(.white)
                        })
                }
                .padding()
            }
            .navigationBarTitle("Text Recognition")
        }
//        .sheet(isPresented: $showingScanningView) {
//            ZStack {
//                LiveTextViewController(recognizedText: $recognizedText)
//
//                Text(recognizedText)
//                    .padding()
//                    .offset(y: 250)
//
//                Image(systemName: "plus")
//                    .font(.title2)
//                    .foregroundColor(.blue.opacity(0.75))
//            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
